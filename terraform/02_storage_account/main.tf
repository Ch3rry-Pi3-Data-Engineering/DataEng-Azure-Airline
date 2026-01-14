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

resource "random_pet" "storage" {
  length    = 2
  separator = ""
}

locals {
  storage_account_name = var.storage_account_name != null ? var.storage_account_name : substr("${var.storage_account_name_prefix}${random_pet.storage.id}", 0, 24)
  container_names      = toset(var.container_names)
  parameters_file_path = "${path.module}/../../parameters/parameters.json"
  parameters_blob_name = "parameters/parameters.json"
  empty_json_path      = "${path.module}/../../sql_scripts/empty.json"
  last_load_json_path  = "${path.module}/../../sql_scripts/last_load.json"
  empty_json_blob_name = "monitor/emptyjson/empty.json"
  last_load_blob_name  = "monitor/lastload/last_load.json"
}

resource "azurerm_storage_account" "main" {
  name                          = local.storage_account_name
  resource_group_name           = data.azurerm_resource_group.main.name
  location                      = coalesce(var.location, data.azurerm_resource_group.main.location)
  account_tier                  = var.account_tier
  account_replication_type      = var.account_replication_type
  account_kind                  = "StorageV2"
  is_hns_enabled                = var.is_hns_enabled
  min_tls_version               = "TLS1_2"
  public_network_access_enabled = var.public_network_access_enabled

  network_rules {
    default_action = "Allow"
  }

  tags = var.tags
}

resource "azurerm_role_assignment" "storage_blob_contributor" {
  count = var.storage_blob_contributor_object_id != null ? 1 : 0

  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = var.storage_blob_contributor_object_id
}

resource "azurerm_storage_container" "medallion" {
  for_each              = local.container_names
  name                  = each.key
  storage_account_name  = azurerm_storage_account.main.name
  container_access_type = "private"
}

resource "azurerm_storage_blob" "parameters_json" {
  count                  = fileexists(local.parameters_file_path) ? 1 : 0
  name                   = local.parameters_blob_name
  storage_account_name   = azurerm_storage_account.main.name
  storage_container_name = azurerm_storage_container.medallion["bronze"].name
  type                   = "Block"
  source                 = local.parameters_file_path
  content_md5            = filemd5(local.parameters_file_path)
  content_type           = "application/json"
}

resource "azurerm_storage_blob" "monitor_empty_json" {
  count                  = fileexists(local.empty_json_path) ? 1 : 0
  name                   = local.empty_json_blob_name
  storage_account_name   = azurerm_storage_account.main.name
  storage_container_name = azurerm_storage_container.medallion["bronze"].name
  type                   = "Block"
  source                 = local.empty_json_path
  content_md5            = filemd5(local.empty_json_path)
  content_type           = "application/json"
}

resource "azurerm_storage_blob" "monitor_last_load_json" {
  count                  = fileexists(local.last_load_json_path) ? 1 : 0
  name                   = local.last_load_blob_name
  storage_account_name   = azurerm_storage_account.main.name
  storage_container_name = azurerm_storage_container.medallion["bronze"].name
  type                   = "Block"
  source                 = local.last_load_json_path
  content_md5            = filemd5(local.last_load_json_path)
  content_type           = "application/json"
}
