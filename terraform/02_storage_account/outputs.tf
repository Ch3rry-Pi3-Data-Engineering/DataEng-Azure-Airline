output "storage_account_id" {
  value = azurerm_storage_account.main.id
}

output "storage_account_name" {
  value = azurerm_storage_account.main.name
}

output "storage_account_primary_access_key" {
  value     = azurerm_storage_account.main.primary_access_key
  sensitive = true
}

output "primary_blob_endpoint" {
  value = azurerm_storage_account.main.primary_blob_endpoint
}

output "primary_dfs_endpoint" {
  value = azurerm_storage_account.main.primary_dfs_endpoint
}

output "medallion_container_names" {
  value = sort(keys(azurerm_storage_container.medallion))
}
