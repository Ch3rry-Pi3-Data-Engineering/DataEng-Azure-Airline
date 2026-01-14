output "pipeline_name" {
  value = azapi_resource.pipeline.name
}

output "http_dataset_name" {
  value = azapi_resource.http_dataset.name
}

output "sink_dataset_name" {
  value = azurerm_data_factory_dataset_delimited_text.adls_sink.name
}
