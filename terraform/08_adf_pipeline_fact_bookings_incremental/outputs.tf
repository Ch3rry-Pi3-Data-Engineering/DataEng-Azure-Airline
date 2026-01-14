output "pipeline_name" {
  value = azapi_resource.pipeline.name
}

output "sql_dataset_name" {
  value = azurerm_data_factory_dataset_azure_sql_table.sql.name
}

output "json_dataset_name" {
  value = azurerm_data_factory_dataset_json.monitor.name
}

output "parquet_dataset_name" {
  value = azurerm_data_factory_dataset_parquet.adls_sink.name
}
