output "static_web_app_name" {
  value = azurerm_static_web_app.web.name
}

output "web_url" {
  value = "https://${azurerm_static_web_app.web.default_host_name}"
}

output "function_app_name" {
  value = azurerm_function_app_flex_consumption.api.name
}

output "api_url" {
  value = "https://${azurerm_function_app_flex_consumption.api.default_hostname}"
}

output "function_app_principal_id" {
  description = "Object ID of the API's managed identity, used when a migration creates its database user."
  value       = azurerm_function_app_flex_consumption.api.identity[0].principal_id
}

output "key_vault_name" {
  value = azurerm_key_vault.this.name
}

output "key_vault_uri" {
  value = azurerm_key_vault.this.vault_uri
}

output "sql_server_name" {
  value = azurerm_mssql_server.this.name
}

output "sql_server_fqdn" {
  value = azurerm_mssql_server.this.fully_qualified_domain_name
}

output "app_database_name" {
  value = azapi_resource.app_database.name
}
