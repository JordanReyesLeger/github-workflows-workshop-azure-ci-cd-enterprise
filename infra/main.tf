locals {
  # Sufijo determinista: el mismo ambiente siempre da los mismos nombres, y dos
  # suscripciones distintas no chocan en el espacio global de nombres de Storage.
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

module "sitio_web" {
  source = "./modules/sitio-web"

  nombre_cuenta          = "st${var.nombre_app}${var.ambiente}${local.sufijo}"
  grupo_recursos         = azurerm_resource_group.sitio.name
  ubicacion              = azurerm_resource_group.sitio.location
  replicacion            = var.replicacion
  dias_retencion_borrado = var.dias_retencion_borrado
  habilitar_versionado   = var.habilitar_versionado
  etiquetas              = local.etiquetas
}
