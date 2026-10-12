locals {
  # Sufijo determinista: el mismo ambiente siempre da los mismos nombres, y dos
  # suscripciones distintas no chocan en el espacio global de nombres de App Service (azurewebsites.net).
  sufijo = substr(sha1("${var.suscripcion_id}-${var.nombre_app}-${var.ambiente}"), 0, 6)

  etiquetas = merge(
    {
      proyecto         = var.nombre_app
      ambiente         = var.ambiente
      "gestionado-por" = "terraform"
      repositorio      = "taller-cicd-azure"
    },
    var.etiquetas_extra,
  )
}

resource "azurerm_resource_group" "sitio" {
  name     = "rg-${var.nombre_app}-${var.ambiente}"
  location = var.ubicacion
  tags     = local.etiquetas
}

module "web_app" {
  source = "./modules/web-app"

  nombre         = "app-${var.nombre_app}-${var.ambiente}-${local.sufijo}"
  ambiente       = var.ambiente
  grupo_recursos = azurerm_resource_group.sitio.name
  ubicacion      = azurerm_resource_group.sitio.location
  sku_plan       = var.sku_plan
  siempre_activa = var.siempre_activa
  version_dotnet = var.version_dotnet
  etiquetas      = local.etiquetas
}