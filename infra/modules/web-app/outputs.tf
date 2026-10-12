output "url_sitio" {
  description = "Dirección pública de la aplicación."
  value       = "https://${azurerm_linux_web_app.app.default_hostname}"
}

output "nombre_app" {
  description = "Nombre de la Web App."
  value       = azurerm_linux_web_app.app.name
}
