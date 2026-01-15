variable "data_factory_id" {
  type    = string
  default = "/subscriptions/24025df6-7c97-4266-a779-8cf5e3ef87b6/resourceGroups/rg-airline-engaging-sponge/providers/Microsoft.DataFactory/factories/adf-airline-accepted-bulldog"
}

variable "adls_linked_service_name" {
  type    = string
  default = "ls-adls-airline-factual-shad"
}

variable "dataflow_name_prefix" {
  type    = string
  default = "df-airline-gold-smoke"
}

variable "source_container" {
  type    = string
  default = "silver"
}

variable "source_folder" {
  type    = string
  default = "airport"
}

variable "source_delta_folder" {
  type    = string
  default = "fact_bookings.parquet"
}

variable "sink_container" {
  type    = string
  default = "gold"
}

variable "sink_folder" {
  type    = string
  default = "airport"
}

variable "sink_delta_folder" {
  type    = string
  default = "_smoke_test_copy"
}
