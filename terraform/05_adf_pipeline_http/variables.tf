variable "data_factory_id" {
  type        = string
  description = "Data Factory ID that owns the pipeline"
}

variable "http_linked_service_name" {
  type        = string
  description = "Name of the HTTP linked service"
}

variable "adls_linked_service_name" {
  type        = string
  description = "Name of the ADLS Gen2 linked service"
}

variable "pipeline_name" {
  type        = string
  description = "Pipeline name (if null, uses pipeline_name_prefix + random suffix)"
  default     = null
}

variable "pipeline_name_prefix" {
  type        = string
  description = "Prefix used to build the pipeline name when pipeline_name is null"
  default     = "pl-airline-http"
}

variable "http_dataset_name" {
  type        = string
  description = "HTTP dataset name (if null, uses http_dataset_name_prefix + random suffix)"
  default     = null
}

variable "http_dataset_name_prefix" {
  type        = string
  description = "Prefix used to build the HTTP dataset name when http_dataset_name is null"
  default     = "ds_http_airline"
}

variable "parameters_dataset_name" {
  type        = string
  description = "Parameters JSON dataset name (if null, uses parameters_dataset_name_prefix + random suffix)"
  default     = null
}

variable "parameters_dataset_name_prefix" {
  type        = string
  description = "Prefix used to build the parameters dataset name when parameters_dataset_name is null"
  default     = "ds_parameters_airline"
}

variable "sink_dataset_name" {
  type        = string
  description = "ADLS sink dataset name (if null, uses sink_dataset_name_prefix + random suffix)"
  default     = null
}

variable "sink_dataset_name_prefix" {
  type        = string
  description = "Prefix used to build the sink dataset name when sink_dataset_name is null"
  default     = "ds_adls_bronze_airline"
}

variable "parameters_container" {
  type        = string
  description = "ADLS container for the parameters JSON"
  default     = "bronze"
}

variable "parameters_path" {
  type        = string
  description = "Folder path inside the parameters container"
  default     = "parameters"
}

variable "parameters_file" {
  type        = string
  description = "Parameters JSON file name"
  default     = "parameters.json"
}

variable "sink_file_system" {
  type        = string
  description = "ADLS file system (container) for the sink data"
  default     = "bronze"
}
