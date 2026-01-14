output "pipeline_name" {
  value = azapi_resource.pipeline.name
}

output "http_dataset_name" {
  value = azapi_resource.http_json_dataset.name
}

output "sink_dataset_name" {
  value = azapi_resource.adls_json_dataset.name
}
