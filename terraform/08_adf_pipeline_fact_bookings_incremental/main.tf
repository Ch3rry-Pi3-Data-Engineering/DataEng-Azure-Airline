terraform {
  required_version = ">= 1.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "~> 1.13"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "azurerm" {
  features {}
}

provider "azapi" {}

resource "random_pet" "pipeline" {
  length    = 2
  separator = "-"
}

resource "random_pet" "sql_dataset" {
  length    = 2
  separator = "_"
}

resource "random_pet" "json_dataset" {
  length    = 2
  separator = "_"
}

resource "random_pet" "parquet_dataset" {
  length    = 2
  separator = "_"
}

locals {
  pipeline_name = var.pipeline_name != null ? var.pipeline_name : "${var.pipeline_name_prefix}-${random_pet.pipeline.id}"

  sql_dataset_prefix     = replace(var.sql_dataset_name_prefix, "-", "_")
  json_dataset_prefix    = replace(var.json_dataset_name_prefix, "-", "_")
  parquet_dataset_prefix = replace(var.parquet_dataset_name_prefix, "-", "_")

  sql_dataset_name     = var.sql_dataset_name != null ? var.sql_dataset_name : "${local.sql_dataset_prefix}_${random_pet.sql_dataset.id}"
  json_dataset_name    = var.json_dataset_name != null ? var.json_dataset_name : "${local.json_dataset_prefix}_${random_pet.json_dataset.id}"
  parquet_dataset_name = var.parquet_dataset_name != null ? var.parquet_dataset_name : "${local.parquet_dataset_prefix}_${random_pet.parquet_dataset.id}"

  sql_linked_service_id = "${var.data_factory_id}/linkedservices/${var.sql_linked_service_name}"
  sql_table_full        = "${var.sql_schema}.${var.sql_table}"
  lastload_field_name   = "lastload"

  lastload_dataset_params = {
    container = var.monitor_container
    folder    = var.monitor_lastload_folder
    file      = var.monitor_lastload_file
  }

  empty_dataset_params = {
    container = var.monitor_container
    folder    = var.monitor_empty_folder
    file      = var.monitor_empty_file
  }

  sink_dataset_params = {
    container = var.sink_container
    folder    = var.sink_folder
    file      = var.sink_file
  }

  sql_dataset_params = {
    schema = var.sql_schema
    table  = var.sql_table
  }

  latest_load_query = "SELECT MAX(booking_date) as latestload FROM ${local.sql_table_full}"
  incremental_query = <<EOT
SELECT * FROM ${local.sql_table_full}
WHERE booking_date > '@{activity('LastLoad').output.firstRow.${local.lastload_field_name}}'
AND booking_date <= '@{activity('LatestLoad').output.firstRow.latestload}'
EOT

  pipeline_activities = [
    {
      name = "LastLoad"
      type = "Lookup"
      typeProperties = {
        source = {
          type = "JsonSource"
        }
        dataset = {
          referenceName = azurerm_data_factory_dataset_json.monitor.name
          type          = "DatasetReference"
          parameters    = local.lastload_dataset_params
        }
        firstRowOnly = true
      }
    },
    {
      name = "LatestLoad"
      type = "Lookup"
      typeProperties = {
        source = {
          type           = "SqlSource"
          sqlReaderQuery = local.latest_load_query
        }
        dataset = {
          referenceName = azurerm_data_factory_dataset_azure_sql_table.sql.name
          type          = "DatasetReference"
          parameters    = local.sql_dataset_params
        }
        firstRowOnly = true
      }
    },
    {
      name = "CopyFactBookings"
      type = "Copy"
      dependsOn = [
        {
          activity             = "LastLoad"
          dependencyConditions = ["Succeeded"]
        },
        {
          activity             = "LatestLoad"
          dependencyConditions = ["Succeeded"]
        }
      ]
      inputs = [
        {
          referenceName = azurerm_data_factory_dataset_azure_sql_table.sql.name
          type          = "DatasetReference"
          parameters    = local.sql_dataset_params
        }
      ]
      outputs = [
        {
          referenceName = azurerm_data_factory_dataset_parquet.adls_sink.name
          type          = "DatasetReference"
          parameters    = local.sink_dataset_params
        }
      ]
      typeProperties = {
        source = {
          type           = "SqlSource"
          sqlReaderQuery = local.incremental_query
        }
        sink = {
          type = "ParquetSink"
        }
      }
    },
    {
      name = "UpdateLastLoad"
      type = "Copy"
      dependsOn = [
        {
          activity             = "CopyFactBookings"
          dependencyConditions = ["Succeeded"]
        }
      ]
      inputs = [
        {
          referenceName = azurerm_data_factory_dataset_json.monitor.name
          type          = "DatasetReference"
          parameters    = local.empty_dataset_params
        }
      ]
      outputs = [
        {
          referenceName = azurerm_data_factory_dataset_json.monitor.name
          type          = "DatasetReference"
          parameters    = local.lastload_dataset_params
        }
      ]
      typeProperties = {
        source = {
          type = "JsonSource"
          additionalColumns = [
            {
              name  = local.lastload_field_name
              value = "@activity('LatestLoad').output.firstRow.latestload"
            }
          ]
        }
        sink = {
          type = "JsonSink"
        }
      }
    }
  ]

  pipeline_body = {
    properties = {
      activities = local.pipeline_activities
      annotations = []
    }
  }
}

resource "azurerm_data_factory_dataset_json" "monitor" {
  name                = local.json_dataset_name
  data_factory_id     = var.data_factory_id
  linked_service_name = var.adls_linked_service_name
  encoding            = "UTF-8"

  parameters = {
    container = "String"
    folder    = "String"
    file      = "String"
  }

  azure_blob_storage_location {
    container                 = "@{dataset().container}"
    path                      = "@{dataset().folder}"
    filename                  = "@{dataset().file}"
    dynamic_container_enabled = true
    dynamic_path_enabled      = true
    dynamic_filename_enabled  = true
  }
}

resource "azurerm_data_factory_dataset_parquet" "adls_sink" {
  name                = local.parquet_dataset_name
  data_factory_id     = var.data_factory_id
  linked_service_name = var.adls_linked_service_name
  compression_codec   = "snappy"

  parameters = {
    container = "String"
    folder    = "String"
    file      = "String"
  }

  azure_blob_fs_location {
    file_system                 = "@{dataset().container}"
    path                        = "@{dataset().folder}"
    filename                    = "@{dataset().file}"
    dynamic_file_system_enabled = true
    dynamic_path_enabled        = true
    dynamic_filename_enabled    = true
  }
}

resource "azurerm_data_factory_dataset_azure_sql_table" "sql" {
  name              = local.sql_dataset_name
  data_factory_id   = var.data_factory_id
  linked_service_id = local.sql_linked_service_id

  parameters = {
    schema = "String"
    table  = "String"
  }

  schema = "@{dataset().schema}"
  table  = "@{dataset().table}"
}

resource "azapi_resource" "pipeline" {
  type                      = "Microsoft.DataFactory/factories/pipelines@2018-06-01"
  name                      = local.pipeline_name
  parent_id                 = var.data_factory_id
  body                      = jsonencode(local.pipeline_body)
  schema_validation_enabled = false

  depends_on = [
    azurerm_data_factory_dataset_json.monitor,
    azurerm_data_factory_dataset_parquet.adls_sink,
    azurerm_data_factory_dataset_azure_sql_table.sql,
  ]
}
