# main.tf
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
  dataflow_name = var.dataflow_name != null ? var.dataflow_name : "${var.dataflow_name_prefix}-${random_pet.dataflow.id}"

  airline_source_path  = "${var.source_folder}/${var.airline_source_file}"
  bookings_source_path = "${var.source_folder}/${var.bookings_source_file}"
  sink_path            = "${var.sink_folder}/${var.sink_name}"

  # Notes:
  # - Use ADF script scoping syntax with @ (e.g., factBookings@airline_id) to avoid context errors.
  # - Avoid referencing upstream streams inside select() after join (ADF parser/runtime is picky).
  # - Use rank + filter for Top 5 (more reliable than window syntax variations).
  dataflow_script_lines = [
    "source(output(booking_id as integer, passenger_id as integer, flight_id as integer, airline_id as integer, origin_airport_id as integer, destination_airport_id as integer, booking_date as date, ticket_cost as decimal(10,2), flight_duration_mins as integer, checkin_status as string), allowSchemaDrift: true, validateSchema: false, ignoreNoFilesFound: false, store: 'AzureBlobFS', format: 'delta', fileSystem: '${var.source_container}', folderPath: '${local.bookings_source_path}') ~> factBookings",
    "source(output(airline_id as integer, airline_name as string, country as string), allowSchemaDrift: true, validateSchema: false, ignoreNoFilesFound: false, store: 'AzureBlobFS', format: 'delta', fileSystem: '${var.source_container}', folderPath: '${local.airline_source_path}') ~> airline",

    "factBookings, airline join(factBookings@airline_id === airline@airline_id, joinType:'left', matchType:'exact', ignoreSpaces:false, broadcast:'auto') ~> join1",

    # Aggregate ticket cost by airline name
    "join1 aggregate(groupBy(airline_name), total_sales = sum(ticket_cost)) ~> aggregate1",

    # Rank by total_sales DESC (rank 1 = highest sales)
    "aggregate1 rank(desc(total_sales, true), output(top_sales_rank as long)) ~> rank1",

    # Keep Top 5 only
    "rank1 filter(top_sales_rank <= 5) ~> fltTop",

    # Optional alterRow (kept because it exists in your manual working flow shape)
    "fltTop alterRow(upsertIf(true())) ~> alterRow1",

    # Write to a dedicated gold folder
    "alterRow1 sink(allowSchemaDrift: true, validateSchema: false, store: 'AzureBlobFS', format: 'delta', fileSystem: '${var.sink_container}', folderPath: '${local.sink_path}', insertable: true, updateable: false, upsertable: false, deletable: false, mergeSchema: false, autoCompact: false, optimizedWrite: false, vacuum: 0, preCommands: [], postCommands: [], skipDuplicateMapInputs: true, skipDuplicateMapOutputs: true) ~> sinkGold"
  ]

  dataflow_body = {
    properties = {
      type = "MappingDataFlow"
      typeProperties = {
        sources = [
          {
            name = "factBookings"
            linkedService = {
              referenceName = var.adls_linked_service_name
              type          = "LinkedServiceReference"
            }
          },
          {
            name = "airline"
            linkedService = {
              referenceName = var.adls_linked_service_name
              type          = "LinkedServiceReference"
            }
          }
        ]

        transformations = [
          { name = "join1" },
          { name = "aggregate1" },
          { name = "rank1" },
          { name = "fltTop" },
          { name = "alterRow1" }
        ]

        sinks = [
          {
            name = "sinkGold"
            linkedService = {
              referenceName = var.adls_linked_service_name
              type          = "LinkedServiceReference"
            }
            rejectedDataLinkedService = {
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
  type                      = "Microsoft.DataFactory/factories/dataflows@2018-06-01"
  name                      = local.dataflow_name
  parent_id                 = var.data_factory_id
  body                      = jsonencode(local.dataflow_body)
  schema_validation_enabled = false
}
