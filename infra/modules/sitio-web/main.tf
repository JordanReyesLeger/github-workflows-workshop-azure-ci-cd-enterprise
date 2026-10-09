resource "azurerm_storage_account" "sitio" {
  # Excepciones documentadas del escáner de seguridad (checkov). Cada una tiene su motivo:
  #checkov:skip=CKV_AZURE_59:El sitio web estático es público a propósito; el contenedor sigue sin acceso anónimo.
  #checkov:skip=CKV2_AZURE_33:Un endpoint privado haría el sitio inaccesible desde Internet.
  #checkov:skip=CKV_AZURE_33:No se usa el servicio de colas.
  #checkov:skip=CKV_AZURE_206:dev usa LRS para ahorrar costo; prod usa GRS (ver environments/prod.tfvars).
  #checkov:skip=CKV2_AZURE_1:Contenido público sin datos sensibles; las llaves administradas por Microsoft bastan.
  name                = var.nombre_cuenta
  resource_group_name = var.grupo_recursos
  location            = var.ubicacion

  account_kind             = "StorageV2"
  account_tier             = "Standard"
  account_replication_type = var.replicacion

  # Seguridad por omisión: solo HTTPS, TLS 1.2 y sin llaves de acceso.
  # El pipeline publica con su identidad de Entra (OIDC), nunca con una llave.
  https_traffic_only_enabled      = true
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = false
  default_to_oauth_authentication = true

  blob_properties {
    versioning_enabled = var.habilitar_versionado

    delete_retention_policy {
      days = var.dias_retencion_borrado
    }

    container_delete_retention_policy {
      days = var.dias_retencion_borrado
    }
  }

  tags = var.etiquetas
}

# Crea el contenedor $web y activa el endpoint de sitio web estático.
resource "azurerm_storage_account_static_website" "sitio" {
  storage_account_id = azurerm_storage_account.sitio.id
  index_document     = "index.html"
  error_404_document = "404.html"
}
