variable "data_factory_id" {
  type        = string
  description = "Resource ID of the Azure Data Factory instance"
}

variable "http_linked_service_name" {
  type        = string
  description = "Name of the HTTP linked service in ADF"
}

variable "adls_linked_service_name" {
  type        = string
  description = "Name of the ADLS Gen2 linked service in ADF"
}

variable "pipeline_name" {
  type        = string
  description = "ADF pipeline name (if null, uses pipeline_name_prefix + random suffix)"
  default     = null
}

variable "pipeline_name_prefix" {
  type        = string
  description = "Prefix used to build the pipeline name when pipeline_name is null"
  default     = "pl-airline-airport-json"
}

variable "http_dataset_name" {
  type        = string
  description = "HTTP JSON dataset name (if null, uses http_dataset_name_prefix + random suffix)"
  default     = null
}

variable "http_dataset_name_prefix" {
  type        = string
  description = "Prefix used to build the HTTP JSON dataset name when http_dataset_name is null"
  default     = "ds_http_airport_json"
}

variable "sink_dataset_name" {
  type        = string
  description = "ADLS JSON dataset name (if null, uses sink_dataset_name_prefix + random suffix)"
  default     = null
}

variable "sink_dataset_name_prefix" {
  type        = string
  description = "Prefix used to build the ADLS JSON dataset name when sink_dataset_name is null"
  default     = "ds_adls_bronze_airport_json"
}

variable "sink_file_system" {
  type        = string
  description = "ADLS Gen2 filesystem to store the airport JSON"
  default     = "bronze"
}

variable "sink_folder" {
  type        = string
  description = "Folder path in the sink filesystem"
  default     = "airport"
}

variable "sink_file" {
  type        = string
  description = "Filename for the airport JSON sink"
  default     = "airport.json"
}

variable "airport_url" {
  type        = string
  description = "Full URL to the airport JSON file for the web activity"
  default     = "https://raw.githubusercontent.com/Ch3rry-Pi3-Data-Engineering/DataEng-Azure-Airline/refs/heads/main/data/DimAirport.json"
}

variable "airport_rel_url" {
  type        = string
  description = "Relative URL (from the HTTP linked service base) to the airport JSON file"
  default     = "Ch3rry-Pi3-Data-Engineering/DataEng-Azure-Airline/refs/heads/main/data/DimAirport.json"
}
