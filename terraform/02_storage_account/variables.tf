variable "resource_group_name" {
  type        = string
  description = "Name of the existing resource group"
}

variable "location" {
  type        = string
  description = "Azure region for the storage account (defaults to RG location if null)"
  default     = null
}

variable "storage_account_name" {
  type        = string
  description = "Storage account name (if null, uses storage_account_name_prefix + random suffix)"
  default     = null
}

variable "storage_blob_contributor_object_id" {
  type        = string
  description = "Optional object ID (user/group/SP) to grant Storage Blob Data Contributor on the storage account"
  default     = null
}

variable "storage_account_name_prefix" {
  type        = string
  description = "Prefix used to build the storage account name when storage_account_name is null"
  default     = "stairline"
}

variable "account_tier" {
  type        = string
  description = "Storage account tier"
  default     = "Standard"
}

variable "account_replication_type" {
  type        = string
  description = "Storage account replication type"
  default     = "LRS"
}

variable "is_hns_enabled" {
  type        = bool
  description = "Enable hierarchical namespace (ADLS Gen2)"
  default     = true
}

variable "public_network_access_enabled" {
  type        = bool
  description = "Allow public network access"
  default     = true
}

variable "container_names" {
  type        = list(string)
  description = "Containers created for the medallion architecture"
  default     = ["bronze", "silver", "gold"]
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to the storage account"
  default     = {}
}
