variable "resource_group_name" {
  type        = string
  description = "Name of the existing resource group"
}

variable "location" {
  type        = string
  description = "Azure region for the SQL server (defaults to RG location if null)"
  default     = null
}

variable "sql_server_name" {
  type        = string
  description = "SQL server name (if null, uses sql_server_name_prefix + random suffix)"
  default     = null
}

variable "sql_server_name_prefix" {
  type        = string
  description = "Prefix used to build the SQL server name when sql_server_name is null"
  default     = "sql-airline"
}

variable "sql_admin_login" {
  type        = string
  description = "SQL admin login"
  default     = "sqladmin"
}

variable "sql_admin_password" {
  type        = string
  description = "SQL admin password"
  sensitive   = true
}

variable "azuread_admin_login" {
  type        = string
  description = "Microsoft Entra admin login (user UPN)"
}

variable "azuread_admin_object_id" {
  type        = string
  description = "Microsoft Entra admin object id (defaults to current principal if null)"
  default     = null
}

variable "database_name" {
  type        = string
  description = "SQL database name"
  default     = "airline-dev"
}

variable "database_sku_name" {
  type        = string
  description = "SQL database SKU"
  default     = "GP_S_Gen5_1"
}

variable "max_size_gb" {
  type        = number
  description = "SQL database max size in GB"
  default     = 1
}

variable "min_capacity" {
  type        = number
  description = "Minimum vCores for serverless compute"
  default     = 0.5
}

variable "auto_pause_delay_in_minutes" {
  type        = number
  description = "Auto-pause delay in minutes for serverless compute"
  default     = 60
}

variable "zone_redundant" {
  type        = bool
  description = "Whether the database is zone redundant"
  default     = false
}

variable "public_network_access_enabled" {
  type        = bool
  description = "Whether public network access is enabled for the SQL server"
  default     = true
}

variable "client_ip_address" {
  type        = string
  description = "Client public IP address allowed to access the SQL server (optional)"
  default     = null
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to the SQL server"
  default     = {}
}
