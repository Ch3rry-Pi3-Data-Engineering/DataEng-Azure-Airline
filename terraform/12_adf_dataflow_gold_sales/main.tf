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

resource "random_pet" "dataset" {
  length    = 2
  separator = "_"
}

locals {
  dataflow_name = var.dataflow_name != null ? var.dataflow_name : "${var.dataflow_name_prefix}-${random_pet.dataflow.id}"

  airline_source_dataset_name  = var.airline_source_dataset_name != null ? var.airline_source_dataset_name : "${var.airline_source_dataset_name_prefix}_${random_pet.dataset.id}"
  bookings_source_dataset_name = var.bookings_source_dataset_name != null ? var.bookings_source_dataset_name : "${var.bookings_source_dataset_name_prefix}_${random_pet.dataset.id}"

  airline_source_path  = "${var.source_folder}/${var.airline_source_file}"
  bookings_source_path = "${var.source_folder}/${var.bookings_source_file}"
  sink_path            = "${var.sink_folder}/${var.sink_name}"

  dataflow_script_lines = [
    "source(output(booking_id as integer, passenger_id as integer, flight_id as integer, airline_id as integer, origin_airport_id as integer, destination_airport_id as integer, booking_date as date, ticket_cost as decimal(10,2), flight_duration_mins as integer, checkin_status as string), allowSchemaDrift: true, validateSchema: false, ignoreNoFilesFound: false, format: 'delta') ~> srcBookings",
    "source(output(airline_id as integer, airline_name as string, country as string), allowSchemaDrift: true, validateSchema: false, ignoreNoFilesFound: false, format: 'delta') ~> srcAirline",
    "srcBookings, srcAirline join(srcBookings.airline_id == srcAirline.airline_id, joinType: 'left') ~> jnBookings",
    "jnBookings select(mapColumn(airline_id = srcBookings.airline_id, airline_name = srcAirline.airline_name, ticket_cost = srcBookings.ticket_cost), skipDuplicateMapInputs: true, skipDuplicateMapOutputs: true) ~> slBookings",
    "slBookings aggregate(groupBy(airline_name), total_sales = sum(ticket_cost)) ~> aggSales",
    "aggSales window(over(orderBy: [total_sales desc]), top_sales = denseRank()) ~> winSales",
    "winSales filter(top_sales <= 5) ~> fltTop",
    "fltTop alterRow(upsertIf(true())) ~> arTop",
    "arTop sink(allowSchemaDrift: true, validateSchema: false, format: 'delta', fileSystem: '${var.sink_container}', folderPath: '${local.sink_path}', compressionType: 'snappy', updateMethod: 'upsert', keyColumns: ['airline_name']) ~> sinkGold",
  ]

  dataflow_body = {
    properties = {
      type = "MappingDataFlow"
      typeProperties = {
        sources = [
          {
            name = "srcBookings"
            dataset = {
              referenceName = azapi_resource.bookings_source_dataset.name
              type          = "DatasetReference"
            }
          },
          {
            name = "srcAirline"
            dataset = {
              referenceName = azapi_resource.airline_source_dataset.name
              type          = "DatasetReference"
            }
          }
        ]
        transformations = [
          { name = "jnBookings" },
          { name = "slBookings" },
          { name = "aggSales" },
          { name = "winSales" },
          { name = "fltTop" },
          { name = "arTop" }
        ]
        sinks = [
          { name = "sinkGold" }
        ]
        scriptLines = local.dataflow_script_lines
      }
    }
  }
}

resource "azapi_resource" "airline_source_dataset" {
  type                      = "Microsoft.DataFactory/factories/datasets@2018-06-01"
  name                      = local.airline_source_dataset_name
  parent_id                 = var.data_factory_id
  schema_validation_enabled = false

  body = jsonencode({
    properties = {
      linkedServiceName = {
        referenceName = var.adls_linked_service_name
        type          = "LinkedServiceReference"
      }
      type = "Delta"
      typeProperties = {
        location = {
          type       = "AzureBlobFSLocation"
          fileSystem = var.source_container
          folderPath = local.airline_source_path
        }
      }
    }
  })
}

resource "azapi_resource" "bookings_source_dataset" {
  type                      = "Microsoft.DataFactory/factories/datasets@2018-06-01"
  name                      = local.bookings_source_dataset_name
  parent_id                 = var.data_factory_id
  schema_validation_enabled = false

  body = jsonencode({
    properties = {
      linkedServiceName = {
        referenceName = var.adls_linked_service_name
        type          = "LinkedServiceReference"
      }
      type = "Delta"
      typeProperties = {
        location = {
          type       = "AzureBlobFSLocation"
          fileSystem = var.source_container
          folderPath = local.bookings_source_path
        }
      }
    }
  })
}

resource "azapi_resource" "dataflow" {
  type                      = "Microsoft.DataFactory/factories/dataflows@2018-06-01"
  name                      = local.dataflow_name
  parent_id                 = var.data_factory_id
  body                      = jsonencode(local.dataflow_body)
  schema_validation_enabled = false

  depends_on = [
    azapi_resource.airline_source_dataset,
    azapi_resource.bookings_source_dataset,
  ]
}
