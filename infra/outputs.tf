output "url_sitio" {
  description = "Dirección pública del sitio."
  value       = module.sitio_web.url_sitio
}

output "nombre_cuenta" {
  description = "Cuenta de almacenamiento donde se publica el sitio."
  value       = module.sitio_web.nombre_cuenta
}

output "grupo_recursos" {
  description = "Grupo de recursos del ambiente."
  value       = azurerm_resource_group.sitio.name
}
