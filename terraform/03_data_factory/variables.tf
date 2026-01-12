variable "resource_group_name" {
  type        = string
  description = "Name of the existing resource group"
}

variable "location" {
  type        = string
  description = "Azure region for the data factory (defaults to RG location if null)"
  default     = null
}

variable "data_factory_name" {
  type        = string
  description = "Data factory name (if null, uses data_factory_name_prefix + random suffix)"
  default     = null
}

variable "data_factory_name_prefix" {
  type        = string
  description = "Prefix used to build the data factory name when data_factory_name is null"
  default     = "adf-airline"
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to the data factory"
  default     = {}
}
