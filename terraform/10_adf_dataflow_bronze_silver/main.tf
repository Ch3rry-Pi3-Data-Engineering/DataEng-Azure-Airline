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

  airline_source_dataset_name   = var.airline_source_dataset_name != null ? var.airline_source_dataset_name : "${var.airline_source_dataset_name_prefix}_${random_pet.dataset.id}"
  flight_source_dataset_name    = var.flight_source_dataset_name != null ? var.flight_source_dataset_name : "${var.flight_source_dataset_name_prefix}_${random_pet.dataset.id}"
  passenger_source_dataset_name = var.passenger_source_dataset_name != null ? var.passenger_source_dataset_name : "${var.passenger_source_dataset_name_prefix}_${random_pet.dataset.id}"
  airport_source_dataset_name   = var.airport_source_dataset_name != null ? var.airport_source_dataset_name : "${var.airport_source_dataset_name_prefix}_${random_pet.dataset.id}"
  bookings_source_dataset_name  = var.bookings_source_dataset_name != null ? var.bookings_source_dataset_name : "${var.bookings_source_dataset_name_prefix}_${random_pet.dataset.id}"

  sink_airline_path   = "${var.sink_folder}/${var.airline_sink_file}"
  sink_flight_path    = "${var.sink_folder}/${var.flight_sink_file}"
  sink_passenger_path = "${var.sink_folder}/${var.passenger_sink_file}"
  sink_airport_path   = "${var.sink_folder}/${var.airport_sink_file}"
  sink_bookings_path  = "${var.sink_folder}/${var.bookings_sink_file}"

  dataflow_script_lines = [
    "source(output(airline_id as integer, airline_name as string, country as string), allowSchemaDrift: true, validateSchema: false, ignoreNoFilesFound: false, format: 'delimited') ~> srcAirline",
    "source(output(flight_id as integer, flight_number as string, departure_time as string, arrival_time as string), allowSchemaDrift: true, validateSchema: false, ignoreNoFilesFound: false, format: 'delimited') ~> srcFlight",
    "source(output(passenger_id as integer, full_name as string, gender as string, age as integer, country as string), allowSchemaDrift: true, validateSchema: false, ignoreNoFilesFound: false, format: 'delimited') ~> srcPassenger",
    "source(output(airport_id as integer, airport_name as string, city as string, country as string), allowSchemaDrift: true, validateSchema: false, ignoreNoFilesFound: false, format: 'json') ~> srcAirport",
    "source(output(booking_id as integer, passenger_id as integer, flight_id as integer, airline_id as integer, origin_airport_id as integer, destination_airport_id as integer, booking_date as date, ticket_cost as decimal(10,2), seat_number as integer, paid as string), allowSchemaDrift: true, validateSchema: false, ignoreNoFilesFound: false, format: 'parquet') ~> srcBookings",
    "srcAirline derive(airline_name_clean = trim(airline_name), country_upper = upper(country)) ~> drAirline",
    "srcFlight derive(flight_prefix = substring(flight_number, 1, 2), departure_ts = toTimestamp(concat('1970-01-01 ', departure_time), 'yyyy-MM-dd HH:mm'), arrival_ts = toTimestamp(concat('1970-01-01 ', arrival_time), 'yyyy-MM-dd HH:mm')) ~> drFlight",
    "srcPassenger derive(full_name_clean = trim(full_name), gender_full = iif(gender == 'M', 'Male', 'Female'), age_band = iif(age < 18, 'child', iif(age < 65, 'adult', 'senior'))) ~> drPassenger",
    "srcAirport derive(airport_name_clean = trim(airport_name), city_upper = upper(city)) ~> drAirport",
    "srcBookings derive(booking_year = year(booking_date), booking_month = month(booking_date), is_paid = iif(paid == 'Yes', true(), false())) ~> drBookings",
    "drAirline alterRow(upsertIf(true())) ~> arAirline",
    "drFlight alterRow(upsertIf(true())) ~> arFlight",
    "drPassenger alterRow(upsertIf(true())) ~> arPassenger",
    "drAirport alterRow(upsertIf(true())) ~> arAirport",
    "drBookings alterRow(upsertIf(true())) ~> arBookings",
    "arAirline sink(allowSchemaDrift: true, validateSchema: false, format: 'delta', fileSystem: '${var.sink_container}', folderPath: '${local.sink_airline_path}', compressionType: 'snappy', updateMethod: 'upsert', keyColumns: ['airline_id']) ~> sinkAirline",
    "arFlight sink(allowSchemaDrift: true, validateSchema: false, format: 'delta', fileSystem: '${var.sink_container}', folderPath: '${local.sink_flight_path}', compressionType: 'snappy', updateMethod: 'upsert', keyColumns: ['flight_id']) ~> sinkFlight",
    "arPassenger sink(allowSchemaDrift: true, validateSchema: false, format: 'delta', fileSystem: '${var.sink_container}', folderPath: '${local.sink_passenger_path}', compressionType: 'snappy', updateMethod: 'upsert', keyColumns: ['passenger_id']) ~> sinkPassenger",
    "arAirport sink(allowSchemaDrift: true, validateSchema: false, format: 'delta', fileSystem: '${var.sink_container}', folderPath: '${local.sink_airport_path}', compressionType: 'snappy', updateMethod: 'upsert', keyColumns: ['airport_id']) ~> sinkAirport",
    "arBookings sink(allowSchemaDrift: true, validateSchema: false, format: 'delta', fileSystem: '${var.sink_container}', folderPath: '${local.sink_bookings_path}', compressionType: 'snappy', updateMethod: 'upsert', keyColumns: ['booking_id']) ~> sinkBookings",
  ]

  dataflow_body = {
    properties = {
      type = "MappingDataFlow"
      typeProperties = {
        sources = [
          {
            name = "srcAirline"
            dataset = {
              referenceName = azurerm_data_factory_dataset_delimited_text.airline_source.name
              type          = "DatasetReference"
            }
          },
          {
            name = "srcFlight"
            dataset = {
              referenceName = azurerm_data_factory_dataset_delimited_text.flight_source.name
              type          = "DatasetReference"
            }
          },
          {
            name = "srcPassenger"
            dataset = {
              referenceName = azurerm_data_factory_dataset_delimited_text.passenger_source.name
              type          = "DatasetReference"
            }
          },
          {
            name = "srcAirport"
            dataset = {
              referenceName = azapi_resource.airport_source_dataset.name
              type          = "DatasetReference"
            }
          },
          {
            name = "srcBookings"
            dataset = {
              referenceName = azurerm_data_factory_dataset_parquet.bookings_source.name
              type          = "DatasetReference"
            }
          }
        ]
        transformations = [
          { name = "drAirline" },
          { name = "drFlight" },
          { name = "drPassenger" },
          { name = "drAirport" },
          { name = "drBookings" },
          { name = "arAirline" },
          { name = "arFlight" },
          { name = "arPassenger" },
          { name = "arAirport" },
          { name = "arBookings" },
        ]
        sinks = [
          { name = "sinkAirline" },
          { name = "sinkFlight" },
          { name = "sinkPassenger" },
          { name = "sinkAirport" },
          { name = "sinkBookings" }
        ]
        scriptLines = local.dataflow_script_lines
      }
    }
  }
}

resource "azurerm_data_factory_dataset_delimited_text" "airline_source" {
  name                = local.airline_source_dataset_name
  data_factory_id     = var.data_factory_id
  linked_service_name = var.adls_linked_service_name

  column_delimiter    = ","
  row_delimiter       = "\n"
  first_row_as_header = true
  encoding            = "UTF-8"

  azure_blob_fs_location {
    file_system = var.source_container
    path        = var.source_folder
    filename    = var.airline_source_file
  }
}

resource "azurerm_data_factory_dataset_delimited_text" "flight_source" {
  name                = local.flight_source_dataset_name
  data_factory_id     = var.data_factory_id
  linked_service_name = var.adls_linked_service_name

  column_delimiter    = ","
  row_delimiter       = "\n"
  first_row_as_header = true
  encoding            = "UTF-8"

  azure_blob_fs_location {
    file_system = var.source_container
    path        = var.source_folder
    filename    = var.flight_source_file
  }
}

resource "azurerm_data_factory_dataset_delimited_text" "passenger_source" {
  name                = local.passenger_source_dataset_name
  data_factory_id     = var.data_factory_id
  linked_service_name = var.adls_linked_service_name

  column_delimiter    = ","
  row_delimiter       = "\n"
  first_row_as_header = true
  encoding            = "UTF-8"

  azure_blob_fs_location {
    file_system = var.source_container
    path        = var.source_folder
    filename    = var.passenger_source_file
  }
}

resource "azapi_resource" "airport_source_dataset" {
  type                      = "Microsoft.DataFactory/factories/datasets@2018-06-01"
  name                      = local.airport_source_dataset_name
  parent_id                 = var.data_factory_id
  schema_validation_enabled = false

  body = jsonencode({
    properties = {
      linkedServiceName = {
        referenceName = var.adls_linked_service_name
        type          = "LinkedServiceReference"
      }
      type = "Json"
      typeProperties = {
        location = {
          type       = "AzureBlobFSLocation"
          fileSystem = var.source_container
          folderPath = var.source_folder
          fileName   = var.airport_source_file
        }
        encodingName = "UTF-8"
        filePattern  = "setOfObjects"
      }
    }
  })
}

resource "azurerm_data_factory_dataset_parquet" "bookings_source" {
  name                = local.bookings_source_dataset_name
  data_factory_id     = var.data_factory_id
  linked_service_name = var.adls_linked_service_name

  azure_blob_fs_location {
    file_system = var.source_container
    path        = var.source_folder
    filename    = var.bookings_source_file
  }
}

resource "azapi_resource" "dataflow" {
  type                      = "Microsoft.DataFactory/factories/dataflows@2018-06-01"
  name                      = local.dataflow_name
  parent_id                 = var.data_factory_id
  body                      = jsonencode(local.dataflow_body)
  schema_validation_enabled = false

  depends_on = [
    azurerm_data_factory_dataset_delimited_text.airline_source,
    azurerm_data_factory_dataset_delimited_text.flight_source,
    azurerm_data_factory_dataset_delimited_text.passenger_source,
    azapi_resource.airport_source_dataset,
    azurerm_data_factory_dataset_parquet.bookings_source,
  ]
}
