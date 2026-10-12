output "url_sitio" {
  description = "Dirección pública de la aplicación."
  value       = module.web_app.url_sitio
}

output "nombre_app" {
  description = "Nombre de la Web App donde se despliega la aplicación."
  value       = module.web_app.nombre_app
}

output "grupo_recursos" {
  description = "Grupo de recursos del ambiente."
  value       = azurerm_resource_group.sitio.name
}
