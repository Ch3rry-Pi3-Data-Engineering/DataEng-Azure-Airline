variable "data_factory_id" {
  type        = string
  description = "Data Factory ID that owns the linked services"
}

variable "http_linked_service_name" {
  type        = string
  description = "Name of the HTTP linked service (if null, uses http_linked_service_name_prefix + random suffix)"
  default     = null
}

variable "http_linked_service_name_prefix" {
  type        = string
  description = "Prefix used to build the HTTP linked service name when http_linked_service_name is null"
  default     = "ls-http-airline"
}

variable "http_base_url" {
  type        = string
  description = "Base URL for the HTTP linked service"
  default     = "https://raw.githubusercontent.com"
}

variable "http_authentication_type" {
  type        = string
  description = "Authentication type for the HTTP linked service"
  default     = "Anonymous"
}

variable "http_enable_certificate_validation" {
  type        = bool
  description = "Enable server certificate validation for the HTTP linked service"
  default     = true
}

variable "adls_linked_service_name" {
  type        = string
  description = "Name of the ADLS Gen2 linked service (if null, uses adls_linked_service_name_prefix + random suffix)"
  default     = null
}

variable "adls_linked_service_name_prefix" {
  type        = string
  description = "Prefix used to build the ADLS Gen2 linked service name when adls_linked_service_name is null"
  default     = "ls-adls-airline"
}

variable "sql_linked_service_name" {
  type        = string
  description = "Name of the Azure SQL Database linked service (if null, uses sql_linked_service_name_prefix + random suffix)"
  default     = null
}

variable "sql_linked_service_name_prefix" {
  type        = string
  description = "Prefix used to build the Azure SQL Database linked service name when sql_linked_service_name is null"
  default     = "ls-sql-airline"
}

variable "storage_dfs_endpoint" {
  type        = string
  description = "ADLS Gen2 DFS endpoint (https://<account>.dfs.core.windows.net)"
}

variable "storage_account_key" {
  type        = string
  description = "Storage account key for the ADLS Gen2 linked service"
  sensitive   = true
}

variable "sql_server_fqdn" {
  type        = string
  description = "SQL Server FQDN (server.database.windows.net)"
}

variable "sql_database_name" {
  type        = string
  description = "SQL database name"
}

variable "sql_username" {
  type        = string
  description = "SQL authentication username"
}

variable "sql_password" {
  type        = string
  description = "SQL authentication password"
  sensitive   = true
}

variable "description" {
  type        = string
  description = "Linked service description"
  default     = "Linked services for HTTP source, SQL, and ADLS Gen2 sink"
}
