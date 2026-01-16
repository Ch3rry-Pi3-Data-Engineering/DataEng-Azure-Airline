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

locals {
  pipeline_name = var.pipeline_name != null ? var.pipeline_name : "${var.pipeline_name_prefix}-${random_pet.pipeline.id}"

  pipeline_body = {
    properties = {
      activities = [
        {
          name = "run_silver_to_gold_dataflow"
          type = "ExecuteDataFlow"
          typeProperties = {
            dataflow = {
              referenceName = var.dataflow_name
              type          = "DataFlowReference"
            }
            compute = {
              computeType = var.compute_type
              coreCount   = var.core_count
            }
            traceLevel = var.trace_level
          }
        }
      ]
      annotations = []
    }
  }
}

resource "azapi_resource" "pipeline" {
  type                      = "Microsoft.DataFactory/factories/pipelines@2018-06-01"
  name                      = local.pipeline_name
  parent_id                 = var.data_factory_id
  body                      = jsonencode(local.pipeline_body)
  schema_validation_enabled = false
}
