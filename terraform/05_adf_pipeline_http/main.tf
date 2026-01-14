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

  foreach_activity_name = "for_each_file"
  copy_activity_name    = "copy_http_to_adls"

  http_dataset_params = {
    p_rel_url = "@item().p_rel_url"
  }

  sink_dataset_params = {
    p_sink_folder = "@item().p_sink_folder"
    p_sink_file   = "@item().p_sink_file"
  }

  # -----------------------------
  # ForEach items (files to ingest)
  # -----------------------------
  pipeline_files_default = [
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

  # -----------------------------
  # Translators (Objects)
  # ADF tends to keep these when the entire 'translator' is expression-driven,
  # while it may drop nested expression objects under 'mappings'.
  # -----------------------------
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

  # Choose translator object based on the current ForEach item
  translator_expression = "@if(equals(item().p_source_file,'DimPassenger.csv'), pipeline().parameters.p_translator_passenger, if(equals(item().p_source_file,'DimAirline.csv'), pipeline().parameters.p_translator_airline, pipeline().parameters.p_translator_flight))"

  # -----------------------------
  # Pipeline activities
  # -----------------------------
  pipeline_activities = [
    {
      name = local.foreach_activity_name
      type = "ForEach"
      typeProperties = {
        isSequential = true
        items = {
          type  = "Expression"
          value = "@pipeline().parameters.files"
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
              # IMPORTANT: translator itself is expression-driven and returns an Object
              translator = {
                type  = "Expression"
                value = local.translator_expression
              }
            }
          }
        ]
      }
    }
  ]

  # -----------------------------
  # Pipeline body
  # -----------------------------
  pipeline_body = {
    properties = {
      activities = local.pipeline_activities
      parameters = {
        files = {
          type         = "Array"
          defaultValue = local.pipeline_files_default
        }

        # Translator params (Object) instead of mapping arrays
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
      }
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
    azurerm_data_factory_dataset_delimited_text.adls_sink,
  ]
}
