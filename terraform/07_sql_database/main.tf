terraform {
  required_version = ">= 1.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "azurerm" {
  features {}
}

data "azurerm_resource_group" "main" {
  name = var.resource_group_name
}

data "azurerm_client_config" "current" {}

resource "random_pet" "sql" {
  length    = 2
  separator = ""
}

locals {
  server_name = var.sql_server_name != null ? var.sql_server_name : substr("${var.sql_server_name_prefix}${random_pet.sql.id}", 0, 63)
}

resource "azurerm_mssql_server" "main" {
  name                          = local.server_name
  location                      = coalesce(var.location, data.azurerm_resource_group.main.location)
  resource_group_name           = data.azurerm_resource_group.main.name
  version                       = "12.0"
  administrator_login           = var.sql_admin_login
  administrator_login_password  = var.sql_admin_password
  minimum_tls_version           = "1.2"
  public_network_access_enabled = var.public_network_access_enabled
  tags                          = var.tags

  azuread_administrator {
    login_username              = var.azuread_admin_login
    object_id                   = coalesce(var.azuread_admin_object_id, data.azurerm_client_config.current.object_id)
    tenant_id                   = data.azurerm_client_config.current.tenant_id
    azuread_authentication_only = false
  }
}

resource "azurerm_mssql_firewall_rule" "allow_azure_services" {
  name             = "AllowAzureServices"
  server_id        = azurerm_mssql_server.main.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

resource "azurerm_mssql_firewall_rule" "client_ip" {
  count            = var.client_ip_address == null ? 0 : 1
  name             = "ClientIPAddress"
  server_id        = azurerm_mssql_server.main.id
  start_ip_address = var.client_ip_address
  end_ip_address   = var.client_ip_address
}

resource "azurerm_mssql_database" "main" {
  name                        = var.database_name
  server_id                   = azurerm_mssql_server.main.id
  sku_name                    = var.database_sku_name
  max_size_gb                 = var.max_size_gb
  min_capacity                = var.min_capacity
  auto_pause_delay_in_minutes = var.auto_pause_delay_in_minutes
  zone_redundant              = var.zone_redundant
}
