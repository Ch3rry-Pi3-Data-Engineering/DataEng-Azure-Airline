output "http_linked_service_name" {
  value = azapi_resource.http.name
}

output "adls_linked_service_name" {
  value = azurerm_data_factory_linked_service_data_lake_storage_gen2.adls.name
}
