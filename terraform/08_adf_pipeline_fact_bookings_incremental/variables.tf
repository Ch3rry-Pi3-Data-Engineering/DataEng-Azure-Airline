variable "data_factory_id" {
  type        = string
  description = "Data Factory ID that owns the pipeline and datasets"
}

variable "sql_linked_service_name" {
  type        = string
  description = "Name of the Azure SQL Database linked service"
}

variable "adls_linked_service_name" {
  type        = string
  description = "Name of the ADLS Gen2 linked service"
}

variable "pipeline_name" {
  type        = string
  description = "ADF pipeline name (if null, uses pipeline_name_prefix + random suffix)"
  default     = null
}

variable "pipeline_name_prefix" {
  type        = string
  description = "Prefix used to build the pipeline name when pipeline_name is null"
  default     = "pl-airline-bookings"
}

variable "sql_dataset_name" {
  type        = string
  description = "SQL dataset name (if null, uses sql_dataset_name_prefix + random suffix)"
  default     = null
}

variable "sql_dataset_name_prefix" {
  type        = string
  description = "Prefix used to build the SQL dataset name when sql_dataset_name is null"
  default     = "ds_sql_airline"
}

variable "json_dataset_name" {
  type        = string
  description = "JSON dataset name for monitor files (if null, uses json_dataset_name_prefix + random suffix)"
  default     = null
}

variable "json_dataset_name_prefix" {
  type        = string
  description = "Prefix used to build the JSON dataset name when json_dataset_name is null"
  default     = "ds_json_airline"
}

variable "parquet_dataset_name" {
  type        = string
  description = "Parquet dataset name (if null, uses parquet_dataset_name_prefix + random suffix)"
  default     = null
}

variable "parquet_dataset_name_prefix" {
  type        = string
  description = "Prefix used to build the Parquet dataset name when parquet_dataset_name is null"
  default     = "ds_parquet_airline"
}

variable "monitor_container" {
  type        = string
  description = "Container holding the monitor JSON files"
  default     = "bronze"
}

variable "monitor_empty_folder" {
  type        = string
  description = "Folder containing empty.json"
  default     = "monitor/emptyjson"
}

variable "monitor_empty_file" {
  type        = string
  description = "Empty JSON filename"
  default     = "empty.json"
}

variable "monitor_lastload_folder" {
  type        = string
  description = "Folder containing last_load.json"
  default     = "monitor/lastload"
}

variable "monitor_lastload_file" {
  type        = string
  description = "Last load JSON filename"
  default     = "last_load.json"
}

variable "sink_container" {
  type        = string
  description = "ADLS container for the Parquet sink"
  default     = "bronze"
}

variable "sink_folder" {
  type        = string
  description = "Folder for the Parquet sink"
  default     = "airport"
}

variable "sink_file" {
  type        = string
  description = "File name for the Parquet sink"
  default     = "fact_bookings.parquet"
}

variable "sql_schema" {
  type        = string
  description = "SQL schema name"
  default     = "dbo"
}

variable "sql_table" {
  type        = string
  description = "SQL table name"
  default     = "FactBookings"
}
