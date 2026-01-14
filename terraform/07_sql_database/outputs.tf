output "sql_server_id" {
  value = azurerm_mssql_server.main.id
}

output "sql_server_name" {
  value = azurerm_mssql_server.main.name
}

output "sql_server_fqdn" {
  value = azurerm_mssql_server.main.fully_qualified_domain_name
}

output "sql_database_id" {
  value = azurerm_mssql_database.main.id
}

output "sql_database_name" {
  value = azurerm_mssql_database.main.name
}
