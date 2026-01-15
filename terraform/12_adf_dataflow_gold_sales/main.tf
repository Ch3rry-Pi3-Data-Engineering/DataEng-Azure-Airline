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

resource "random_pet" "dataflow" {
  length    = 2
  separator = "-"
}

locals {
  dataflow_name = "${var.dataflow_name_prefix}-${random_pet.dataflow.id}"

  source_path = "${var.source_folder}/${var.source_delta_folder}"
  sink_path   = "${var.sink_folder}/${var.sink_delta_folder}"

  dataflow_script_lines = [
    "source(allowSchemaDrift: true, validateSchema: false, store: 'AzureBlobFS', format: 'delta', fileSystem: '${var.source_container}', folderPath: '${local.source_path}') ~> src",
    "src sink(allowSchemaDrift: true, validateSchema: false, store: 'AzureBlobFS', format: 'delta', fileSystem: '${var.sink_container}', folderPath: '${local.sink_path}') ~> sink"
  ]

  dataflow_body = {
    properties = {
      type = "MappingDataFlow"
      typeProperties = {
        sources = [
          {
            name = "src"
            linkedService = {
              referenceName = var.adls_linked_service_name
              type          = "LinkedServiceReference"
            }
          }
        ]
        transformations = []
        sinks = [
          {
            name = "sink"
            linkedService = {
              referenceName = var.adls_linked_service_name
              type          = "LinkedServiceReference"
            }
          }
        ]
        scriptLines = local.dataflow_script_lines
      }
    }
  }
}

resource "azapi_resource" "dataflow" {
  type      = "Microsoft.DataFactory/factories/dataflows@2018-06-01"
  name      = local.dataflow_name
  parent_id = var.data_factory_id
  body      = jsonencode(local.dataflow_body)

  schema_validation_enabled = false
}
