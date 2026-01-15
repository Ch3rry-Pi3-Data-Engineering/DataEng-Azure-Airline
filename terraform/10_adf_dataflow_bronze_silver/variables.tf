variable "data_factory_id" {
  type        = string
  description = "Data Factory ID that owns the data flow"
}

variable "adls_linked_service_name" {
  type        = string
  description = "Name of the ADLS Gen2 linked service"
}

variable "dataflow_name" {
  type        = string
  description = "Data flow name (if null, uses dataflow_name_prefix + random suffix)"
  default     = null
}

variable "dataflow_name_prefix" {
  type        = string
  description = "Prefix used to build the data flow name when dataflow_name is null"
  default     = "df-airline-bronze-silver"
}

variable "airline_source_dataset_name" {
  type        = string
  description = "Dataset name for airline CSV source"
  default     = null
}

variable "flight_source_dataset_name" {
  type        = string
  description = "Dataset name for flight CSV source"
  default     = null
}

variable "passenger_source_dataset_name" {
  type        = string
  description = "Dataset name for passenger CSV source"
  default     = null
}

variable "airport_source_dataset_name" {
  type        = string
  description = "Dataset name for airport JSON source"
  default     = null
}

variable "bookings_source_dataset_name" {
  type        = string
  description = "Dataset name for fact bookings parquet source"
  default     = null
}

variable "airline_sink_dataset_name" {
  type        = string
  description = "Dataset name for airline parquet sink"
  default     = null
}

variable "flight_sink_dataset_name" {
  type        = string
  description = "Dataset name for flight parquet sink"
  default     = null
}

variable "passenger_sink_dataset_name" {
  type        = string
  description = "Dataset name for passenger parquet sink"
  default     = null
}

variable "airport_sink_dataset_name" {
  type        = string
  description = "Dataset name for airport parquet sink"
  default     = null
}

variable "bookings_sink_dataset_name" {
  type        = string
  description = "Dataset name for fact bookings parquet sink"
  default     = null
}

variable "airline_source_dataset_name_prefix" {
  type        = string
  description = "Prefix for airline CSV source dataset name"
  default     = "ds_bronze_airline_csv"
}

variable "flight_source_dataset_name_prefix" {
  type        = string
  description = "Prefix for flight CSV source dataset name"
  default     = "ds_bronze_flight_csv"
}

variable "passenger_source_dataset_name_prefix" {
  type        = string
  description = "Prefix for passenger CSV source dataset name"
  default     = "ds_bronze_passenger_csv"
}

variable "airport_source_dataset_name_prefix" {
  type        = string
  description = "Prefix for airport JSON source dataset name"
  default     = "ds_bronze_airport_json"
}

variable "bookings_source_dataset_name_prefix" {
  type        = string
  description = "Prefix for fact bookings parquet source dataset name"
  default     = "ds_bronze_fact_bookings_parquet"
}

variable "airline_sink_dataset_name_prefix" {
  type        = string
  description = "Prefix for airline parquet sink dataset name"
  default     = "ds_silver_airline_parquet"
}

variable "flight_sink_dataset_name_prefix" {
  type        = string
  description = "Prefix for flight parquet sink dataset name"
  default     = "ds_silver_flight_parquet"
}

variable "passenger_sink_dataset_name_prefix" {
  type        = string
  description = "Prefix for passenger parquet sink dataset name"
  default     = "ds_silver_passenger_parquet"
}

variable "airport_sink_dataset_name_prefix" {
  type        = string
  description = "Prefix for airport parquet sink dataset name"
  default     = "ds_silver_airport_parquet"
}

variable "bookings_sink_dataset_name_prefix" {
  type        = string
  description = "Prefix for bookings parquet sink dataset name"
  default     = "ds_silver_bookings_parquet"
}

variable "source_container" {
  type        = string
  description = "Source container for bronze data"
  default     = "bronze"
}

variable "source_folder" {
  type        = string
  description = "Source folder within the container"
  default     = "airport"
}

variable "airline_source_file" {
  type        = string
  description = "Airline CSV file name"
  default     = "airline.csv"
}

variable "flight_source_file" {
  type        = string
  description = "Flight CSV file name"
  default     = "flight.csv"
}

variable "passenger_source_file" {
  type        = string
  description = "Passenger CSV file name"
  default     = "passenger.csv"
}

variable "airport_source_file" {
  type        = string
  description = "Airport JSON file name"
  default     = "airport.json"
}

variable "bookings_source_file" {
  type        = string
  description = "Bookings Parquet file name"
  default     = "fact_bookings.parquet"
}

variable "sink_container" {
  type        = string
  description = "Sink container for silver data"
  default     = "silver"
}

variable "sink_folder" {
  type        = string
  description = "Sink folder within the container"
  default     = "airport"
}

variable "airline_sink_file" {
  type        = string
  description = "Airline parquet file name"
  default     = "airline.parquet"
}

variable "flight_sink_file" {
  type        = string
  description = "Flight parquet file name"
  default     = "flight.parquet"
}

variable "passenger_sink_file" {
  type        = string
  description = "Passenger parquet file name"
  default     = "passenger.parquet"
}

variable "airport_sink_file" {
  type        = string
  description = "Airport parquet file name"
  default     = "airport.parquet"
}

variable "bookings_sink_file" {
  type        = string
  description = "Bookings parquet file name"
  default     = "fact_bookings.parquet"
}
