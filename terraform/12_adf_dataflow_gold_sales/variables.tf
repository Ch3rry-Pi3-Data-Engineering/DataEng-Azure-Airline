# variables.tf
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
  default     = "df-airline-gold-sales"
}

variable "source_container" {
  type        = string
  description = "Source container for silver data"
  default     = "silver"
}

variable "source_folder" {
  type        = string
  description = "Source folder within the container"
  default     = "airport"
}

variable "airline_source_file" {
  type        = string
  description = "Airline delta folder name"
  default     = "airline.parquet"
}

variable "bookings_source_file" {
  type        = string
  description = "Bookings delta folder name"
  default     = "fact_bookings.parquet"
}

variable "sink_container" {
  type        = string
  description = "Sink container for gold data"
  default     = "gold"
}

variable "sink_folder" {
  type        = string
  description = "Sink folder within the container"
  default     = "airport"
}

variable "sink_name" {
  type        = string
  description = "Gold output folder name for airline sales"
  default     = "airline_sales_top5"
}
