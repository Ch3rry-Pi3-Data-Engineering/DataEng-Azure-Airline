output "dataflow_name" {
  value = azapi_resource.dataflow.name
}

output "airline_source_dataset_name" {
  value = azurerm_data_factory_dataset_delimited_text.airline_source.name
}

output "flight_source_dataset_name" {
  value = azurerm_data_factory_dataset_delimited_text.flight_source.name
}

output "passenger_source_dataset_name" {
  value = azurerm_data_factory_dataset_delimited_text.passenger_source.name
}

output "airport_source_dataset_name" {
  value = azapi_resource.airport_source_dataset.name
}

output "bookings_source_dataset_name" {
  value = azurerm_data_factory_dataset_parquet.bookings_source.name
}
