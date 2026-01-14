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

resource "random_pet" "http_dataset" {
  length    = 2
  separator = "_"
}

resource "random_pet" "params_dataset" {
  length    = 2
  separator = "_"
}

resource "random_pet" "sink_dataset" {
  length    = 2
  separator = "_"
}

locals {
  http_dataset_prefix   = replace(var.http_dataset_name_prefix, "-", "_")
  params_dataset_prefix = replace(var.parameters_dataset_name_prefix, "-", "_")
  sink_dataset_prefix   = replace(var.sink_dataset_name_prefix, "-", "_")

  pipeline_name        = var.pipeline_name != null ? var.pipeline_name : "${var.pipeline_name_prefix}-${random_pet.pipeline.id}"
  http_dataset_name    = var.http_dataset_name != null ? var.http_dataset_name : "${local.http_dataset_prefix}_${random_pet.http_dataset.id}"
  params_dataset_name  = var.parameters_dataset_name != null ? var.parameters_dataset_name : "${local.params_dataset_prefix}_${random_pet.params_dataset.id}"
  sink_dataset_name    = var.sink_dataset_name != null ? var.sink_dataset_name : "${local.sink_dataset_prefix}_${random_pet.sink_dataset.id}"
  lookup_activity_name = "lookup_parameters"
  foreach_activity_name = "for_each_file"
  copy_activity_name   = "copy_http_to_adls"

  http_dataset_params = {
    p_rel_url = "@item().p_rel_url"
  }

  sink_dataset_params = {
    p_sink_folder = "@item().p_sink_folder"
    p_sink_file   = "@item().p_sink_file"
  }

  pipeline_activities = [
    {
      name = local.lookup_activity_name
      type = "Lookup"
      typeProperties = {
        source = {
          type = "JsonSource"
        }
        dataset = {
          referenceName = azurerm_data_factory_dataset_json.parameters.name
          type          = "DatasetReference"
        }
        firstRowOnly = false
      }
    },
    {
      name = local.foreach_activity_name
      type = "ForEach"
      dependsOn = [
        {
          activity             = local.lookup_activity_name
          dependencyConditions = ["Succeeded"]
        }
      ]
      typeProperties = {
        isSequential = true
        items = {
          type  = "Expression"
          value = "@activity('lookup_parameters').output.value"
        }
        activities = [
          {
            name = local.copy_activity_name
            type = "Copy"
            inputs = [
              {
                referenceName = azapi_resource.http_dataset.name
                type          = "DatasetReference"
                parameters    = local.http_dataset_params
              }
            ]
            outputs = [
              {
                referenceName = azurerm_data_factory_dataset_delimited_text.adls_sink.name
                type          = "DatasetReference"
                parameters    = local.sink_dataset_params
              }
            ]
            typeProperties = {
              source = {
                type = "DelimitedTextSource"
              }
              sink = {
                type = "DelimitedTextSink"
              }
              translator = {
                type = "TabularTranslator"
                mappings = {
                  type  = "Expression"
                  value = "@item().p_mapping"
                }
              }
            }
          }
        ]
      }
    }
  ]

  pipeline_body = {
    properties = {
      activities  = local.pipeline_activities
      annotations = []
    }
  }
}

resource "azapi_resource" "http_dataset" {
  type                      = "Microsoft.DataFactory/factories/datasets@2018-06-01"
  name                      = local.http_dataset_name
  parent_id                 = var.data_factory_id
  schema_validation_enabled = false

  body = jsonencode({
    properties = {
      linkedServiceName = {
        referenceName = var.http_linked_service_name
        type          = "LinkedServiceReference"
      }
      parameters = {
        p_rel_url = {
          type = "String"
        }
      }
      type = "DelimitedText"
      typeProperties = {
        location = {
          type        = "HttpServerLocation"
          relativeUrl = "@{dataset().p_rel_url}"
        }
        columnDelimiter   = ","
        rowDelimiter      = "\n"
        firstRowAsHeader  = true
        quoteChar         = "\""
        escapeChar        = "\\"
        encodingName      = "utf-8"
      }
    }
  })
}

resource "azurerm_data_factory_dataset_json" "parameters" {
  name                = local.params_dataset_name
  data_factory_id     = var.data_factory_id
  linked_service_name = var.adls_linked_service_name
  encoding            = "UTF-8"

  azure_blob_storage_location {
    container = var.parameters_container
    path      = var.parameters_path
    filename  = var.parameters_file
  }
}

resource "azurerm_data_factory_dataset_delimited_text" "adls_sink" {
  name                = local.sink_dataset_name
  data_factory_id     = var.data_factory_id
  linked_service_name = var.adls_linked_service_name

  column_delimiter    = ","
  row_delimiter       = "\n"
  first_row_as_header = true
  encoding            = "UTF-8"

  parameters = {
    p_sink_folder = "String"
    p_sink_file   = "String"
  }

  azure_blob_fs_location {
    file_system              = var.sink_file_system
    path                     = "@{dataset().p_sink_folder}"
    filename                 = "@{dataset().p_sink_file}"
    dynamic_path_enabled     = true
    dynamic_filename_enabled = true
  }
}

resource "azapi_resource" "pipeline" {
  type                      = "Microsoft.DataFactory/factories/pipelines@2018-06-01"
  name                      = local.pipeline_name
  parent_id                 = var.data_factory_id
  body                      = jsonencode(local.pipeline_body)
  schema_validation_enabled = false

  depends_on = [
    azapi_resource.http_dataset,
    azurerm_data_factory_dataset_json.parameters,
    azurerm_data_factory_dataset_delimited_text.adls_sink,
  ]
}
