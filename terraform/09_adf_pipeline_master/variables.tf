variable "data_factory_id" {
  type        = string
  description = "Data Factory ID that owns the pipeline"
}

variable "pipeline_name" {
  type        = string
  description = "ADF pipeline name (if null, uses pipeline_name_prefix + random suffix)"
  default     = null
}

variable "pipeline_name_prefix" {
  type        = string
  description = "Prefix used to build the pipeline name when pipeline_name is null"
  default     = "pl-airline-master"
}

variable "http_pipeline_name" {
  type        = string
  description = "Name of the HTTP CSV pipeline to execute"
}

variable "airport_pipeline_name" {
  type        = string
  description = "Name of the airport JSON pipeline to execute"
}

variable "bookings_pipeline_name" {
  type        = string
  description = "Name of the bookings pipeline to execute"
}

variable "silver_pipeline_name" {
  type        = string
  description = "Name of the silver data flow pipeline to execute"
}

variable "airport_url" {
  type        = string
  description = "Airport JSON URL"
  default     = "https://raw.githubusercontent.com/Ch3rry-Pi3-Data-Engineering/DataEng-Azure-Airline/refs/heads/main/data/DimAirport.json"
}

variable "airport_rel_url" {
  type        = string
  description = "Airport JSON relative URL"
  default     = "Ch3rry-Pi3-Data-Engineering/DataEng-Azure-Airline/refs/heads/main/data/DimAirport.json"
}

variable "files_default" {
  type = list(object({
    p_source_file = string
    p_rel_url     = string
    p_sink_folder = string
    p_sink_file   = string
  }))
  description = "Default files list for the HTTP pipeline parameters"
  default     = null
}
