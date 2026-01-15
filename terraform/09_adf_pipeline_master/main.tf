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

  # -----------------------------
  # ForEach items (files to ingest)
  # -----------------------------
  pipeline_files_default = var.files_default != null ? var.files_default : [
    {
      p_source_file = "DimAirline.csv"
      p_rel_url     = "Ch3rry-Pi3-Data-Engineering/DataEng-Azure-Airline/refs/heads/main/data/DimAirline.csv"
      p_sink_folder = "airport"
      p_sink_file   = "airline.csv"
    },
    {
      p_source_file = "DimFlight.csv"
      p_rel_url     = "Ch3rry-Pi3-Data-Engineering/DataEng-Azure-Airline/refs/heads/main/data/DimFlight.csv"
      p_sink_folder = "airport"
      p_sink_file   = "flight.csv"
    },
    {
      p_source_file = "DimPassenger.csv"
      p_rel_url     = "Ch3rry-Pi3-Data-Engineering/DataEng-Azure-Airline/refs/heads/main/data/DimPassenger.csv"
      p_sink_folder = "airport"
      p_sink_file   = "passenger.csv"
    }
  ]

  # -----------------------------
  # Column mappings (arrays)
  # -----------------------------
  mapping_airline = [
    {
      source = { name = "airline_id", type = "Int64" }
      sink   = { name = "airline_id", type = "Int64" }
    },
    {
      source = { name = "airline_name", type = "String" }
      sink   = { name = "airline_name", type = "String" }
    },
    {
      source = { name = "country", type = "String" }
      sink   = { name = "country", type = "String" }
    }
  ]

  mapping_flight = [
    {
      source = { name = "flight_id", type = "Int64" }
      sink   = { name = "flight_id", type = "Int64" }
    },
    {
      source = { name = "flight_number", type = "String" }
      sink   = { name = "flight_number", type = "String" }
    },
    {
      source = { name = "departure_time", type = "String" }
      sink   = { name = "departure_time", type = "String" }
    },
    {
      source = { name = "arrival_time", type = "String" }
      sink   = { name = "arrival_time", type = "String" }
    }
  ]

  mapping_passenger = [
    {
      source = { name = "passenger_id", type = "Int64" }
      sink   = { name = "passenger_id", type = "Int64" }
    },
    {
      source = { name = "full_name", type = "String" }
      sink   = { name = "full_name", type = "String" }
    },
    {
      source = { name = "gender", type = "String" }
      sink   = { name = "gender", type = "String" }
    },
    {
      source = { name = "age", type = "Int64" }
      sink   = { name = "age", type = "Int64" }
    },
    {
      source = { name = "country", type = "String" }
      sink   = { name = "country", type = "String" }
    }
  ]

  translator_airline = {
    type     = "TabularTranslator"
    mappings = local.mapping_airline
  }

  translator_flight = {
    type     = "TabularTranslator"
    mappings = local.mapping_flight
  }

  translator_passenger = {
    type     = "TabularTranslator"
    mappings = local.mapping_passenger
  }

  pipeline_activities = [
    {
      name = "ExecuteHttpCsvPipeline"
      type = "ExecutePipeline"
      typeProperties = {
        pipeline = {
          referenceName = var.http_pipeline_name
          type          = "PipelineReference"
        }
        waitOnCompletion = true
        parameters = {
          files = {
            type  = "Expression"
            value = "@pipeline().parameters.files"
          }
          p_translator_airline = {
            type  = "Expression"
            value = "@pipeline().parameters.p_translator_airline"
          }
          p_translator_flight = {
            type  = "Expression"
            value = "@pipeline().parameters.p_translator_flight"
          }
          p_translator_passenger = {
            type  = "Expression"
            value = "@pipeline().parameters.p_translator_passenger"
          }
        }
      }
    },
    {
      name = "ExecuteAirportJsonPipeline"
      type = "ExecutePipeline"
      dependsOn = [
        {
          activity             = "ExecuteHttpCsvPipeline"
          dependencyConditions = ["Succeeded"]
        }
      ]
      typeProperties = {
        pipeline = {
          referenceName = var.airport_pipeline_name
          type          = "PipelineReference"
        }
        waitOnCompletion = true
        parameters = {
          p_airport_url = {
            type  = "Expression"
            value = "@pipeline().parameters.p_airport_url"
          }
          p_airport_rel_url = {
            type  = "Expression"
            value = "@pipeline().parameters.p_airport_rel_url"
          }
        }
      }
    },
    {
      name = "ExecuteBookingsPipeline"
      type = "ExecutePipeline"
      dependsOn = [
        {
          activity             = "ExecuteAirportJsonPipeline"
          dependencyConditions = ["Succeeded"]
        }
      ]
      typeProperties = {
        pipeline = {
          referenceName = var.bookings_pipeline_name
          type          = "PipelineReference"
        }
        waitOnCompletion = true
      }
    },
    {
      name = "ExecuteSilverDataflowPipeline"
      type = "ExecutePipeline"
      dependsOn = [
        {
          activity             = "ExecuteBookingsPipeline"
          dependencyConditions = ["Succeeded"]
        }
      ]
      typeProperties = {
        pipeline = {
          referenceName = var.silver_pipeline_name
          type          = "PipelineReference"
        }
        waitOnCompletion = true
      }
    }
  ]

  pipeline_body = {
    properties = {
      activities = local.pipeline_activities
      parameters = {
        files = {
          type         = "Array"
          defaultValue = local.pipeline_files_default
        }
        p_translator_airline = {
          type         = "Object"
          defaultValue = local.translator_airline
        }
        p_translator_flight = {
          type         = "Object"
          defaultValue = local.translator_flight
        }
        p_translator_passenger = {
          type         = "Object"
          defaultValue = local.translator_passenger
        }
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

resource "azapi_resource" "pipeline" {
  type                      = "Microsoft.DataFactory/factories/pipelines@2018-06-01"
  name                      = local.pipeline_name
  parent_id                 = var.data_factory_id
  body                      = jsonencode(local.pipeline_body)
  schema_validation_enabled = false
}
