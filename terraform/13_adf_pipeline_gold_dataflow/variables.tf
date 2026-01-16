variable "data_factory_id" {
  type        = string
  description = "Data Factory ID that owns the pipeline"
}

variable "dataflow_name" {
  type        = string
  description = "Name of the silver-to-gold data flow"
}

variable "pipeline_name" {
  type        = string
  description = "ADF pipeline name (if null, uses pipeline_name_prefix + random suffix)"
  default     = null
}

variable "pipeline_name_prefix" {
  type        = string
  description = "Prefix used to build the pipeline name when pipeline_name is null"
  default     = "pl-airline-gold-dataflow"
}

variable "compute_type" {
  type        = string
  description = "ADF data flow compute type"
  default     = "General"
}

variable "core_count" {
  type        = number
  description = "ADF data flow core count"
  default     = 8
}

variable "trace_level" {
  type        = string
  description = "ADF data flow trace level"
  default     = "Fine"
}
