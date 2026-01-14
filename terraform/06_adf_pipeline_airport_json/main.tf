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

resource "random_pet" "sink_dataset" {
  length    = 2
  separator = "_"
}

locals {
  http_dataset_prefix = replace(var.http_dataset_name_prefix, "-", "_")
  sink_dataset_prefix = replace(var.sink_dataset_name_prefix, "-", "_")

  pipeline_name     = var.pipeline_name != null ? var.pipeline_name : "${var.pipeline_name_prefix}-${random_pet.pipeline.id}"
  http_dataset_name = var.http_dataset_name != null ? var.http_dataset_name : "${local.http_dataset_prefix}_${random_pet.http_dataset.id}"
  sink_dataset_name = var.sink_dataset_name != null ? var.sink_dataset_name : "${local.sink_dataset_prefix}_${random_pet.sink_dataset.id}"

  web_activity_name  = "get_airport_json"
  copy_activity_name = "copy_airport_json_to_adls"

  airport_schema = [
    {
      name = "airport_id"
      type = "Int64"
    },
    {
      name = "airport_name"
      type = "String"
    },
    {
      name = "city"
      type = "String"
    },
    {
      name = "country"
      type = "String"
    }
  ]

  source_dataset_params = {
    p_rel_url = "@pipeline().parameters.p_airport_rel_url"
  }

  sink_dataset_params = {
    p_sink_folder = var.sink_folder
    p_sink_file   = var.sink_file
  }

  pipeline_activities = [
    {
      name = local.web_activity_name
      type = "WebActivity"
      linkedServiceName = {
        referenceName = var.http_linked_service_name
        type          = "LinkedServiceReference"
      }
      typeProperties = {
        url = {
          type  = "Expression"
          value = "@pipeline().parameters.p_airport_url"
        }
        method = "GET"
      }
    },
    {
      name = local.copy_activity_name
      type = "Copy"
      dependsOn = [
        {
          activity             = local.web_activity_name
          dependencyConditions = ["Succeeded"]
        }
      ]
      inputs = [
        {
          referenceName = azapi_resource.http_json_dataset.name
          type          = "DatasetReference"
          parameters    = local.source_dataset_params
        }
      ]
      outputs = [
        {
          referenceName = azapi_resource.adls_json_dataset.name
          type          = "DatasetReference"
          parameters    = local.sink_dataset_params
        }
      ]
      typeProperties = {
        source = {
          type = "JsonSource"
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
      parameters = {
        p_airport_url = {
          type         = "String"
          defaultValue = var.airport_url
        }
        p_airport_rel_url = {
          type         = "String"
          defaultValue = var.airport_rel_url
        }
      }
      annotations = []
    }
  }
}

resource "azapi_resource" "http_json_dataset" {
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
      type = "Json"
      typeProperties = {
        location = {
          type        = "HttpServerLocation"
          relativeUrl = "@{dataset().p_rel_url}"
        }
        encodingName = "UTF-8"
        filePattern  = "setOfObjects"
      }
      schema = local.airport_schema
    }
  })
}

resource "azapi_resource" "adls_json_dataset" {
  type                      = "Microsoft.DataFactory/factories/datasets@2018-06-01"
  name                      = local.sink_dataset_name
  parent_id                 = var.data_factory_id
  schema_validation_enabled = false

  body = jsonencode({
    properties = {
      linkedServiceName = {
        referenceName = var.adls_linked_service_name
        type          = "LinkedServiceReference"
      }
      parameters = {
        p_sink_folder = {
          type = "String"
        }
        p_sink_file = {
          type = "String"
        }
      }
      type = "Json"
      typeProperties = {
        location = {
          type       = "AzureBlobFSLocation"
          fileSystem = var.sink_file_system
          folderPath = "@{dataset().p_sink_folder}"
          fileName   = "@{dataset().p_sink_file}"
        }
        encodingName = "UTF-8"
        filePattern  = "setOfObjects"
      }
      schema = local.airport_schema
    }
  })
}

resource "azapi_resource" "pipeline" {
  type                      = "Microsoft.DataFactory/factories/pipelines@2018-06-01"
  name                      = local.pipeline_name
  parent_id                 = var.data_factory_id
  body                      = jsonencode(local.pipeline_body)
  schema_validation_enabled = false

  depends_on = [
    azapi_resource.http_json_dataset,
    azapi_resource.adls_json_dataset,
  ]
}
