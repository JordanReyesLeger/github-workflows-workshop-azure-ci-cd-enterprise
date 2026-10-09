output "url_sitio" {
  description = "Dirección pública del sitio estático."
  value       = trimsuffix(azurerm_storage_account.sitio.primary_web_endpoint, "/")

  depends_on = [azurerm_storage_account_static_website.sitio]
}

output "nombre_cuenta" {
  description = "Nombre de la cuenta de almacenamiento."
  value       = azurerm_storage_account.sitio.name
}
