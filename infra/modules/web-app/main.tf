resource "azurerm_service_plan" "plan" {
  #checkov:skip=CKV_AZURE_212:Una sola instancia en el taller; el costo es parte del diseño.
  #checkov:skip=CKV_AZURE_225:El taller no usa zonas de disponibilidad.
  #checkov:skip=CKV_AZURE_211:El SKU se elige por ambiente en environments/*.tfvars (dev usa B1 a propósito).
  name                = "asp-${var.nombre}"
  resource_group_name = var.grupo_recursos
  location            = var.ubicacion

  os_type  = "Linux"
  sku_name = var.sku_plan

  tags = var.etiquetas
}

resource "azurerm_linux_web_app" "app" {
  # Excepciones documentadas del escáner de seguridad (checkov). El taller no incluye
  # autenticación, monitoreo ni alta disponibilidad: son decisiones de diseño, no olvidos.
  #checkov:skip=CKV_AZURE_13:La portada es pública a propósito; no hay datos de usuarios que proteger.
  #checkov:skip=CKV_AZURE_17:La app no usa certificados de cliente.
  #checkov:skip=CKV_AZURE_88:La app no monta ningún Azure Files.
  #checkov:skip=CKV_AZURE_222:El acceso público es el objetivo del sitio.
  #checkov:skip=CKV_AZURE_212:Una sola instancia en el taller; el costo es parte del diseño.
  #checkov:skip=CKV_AZURE_225:El plan del taller no usa zonas de disponibilidad.
  #checkov:skip=CKV_AZURE_71:La app no llama a otros servicios de Azure: no necesita identidad administrada.
  #checkov:skip=CKV_AZURE_16:La app no usa autenticación de Entra ID.
  #checkov:skip=CKV_AZURE_65:El taller no incluye Application Insights.
  #checkov:skip=CKV_AZURE_63:El taller no incluye registros de diagnóstico.
  #checkov:skip=CKV_AZURE_66:El taller no incluye registros de diagnóstico.
  #checkov:skip=CKV_AZURE_95:El taller no incluye registros de diagnóstico.
  #checkov:skip=CKV2_AZURE_18:La app no usa cifrado con llaves del cliente.
  name                = var.nombre
  resource_group_name = var.grupo_recursos
  location            = var.ubicacion
  service_plan_id     = azurerm_service_plan.plan.id

  # Seguridad por omisión: solo HTTPS y TLS 1.2.
  https_only                    = true
  public_network_access_enabled = true

  # Sin usuario/contraseña de publicación: el pipeline despliega con su identidad de Entra (OIDC).
  ftp_publish_basic_authentication_enabled       = false
  webdeploy_publish_basic_authentication_enabled = false

  site_config {
    always_on           = var.siempre_activa
    ftps_state          = "Disabled"
    http2_enabled       = true
    minimum_tls_version = "1.2"
    health_check_path   = "/health"
    # Minutos con fallos antes de sacar la instancia de rotación (mínimo 2).
    health_check_eviction_time_in_min = 5

    application_stack {
      dotnet_version = var.version_dotnet
    }
  }

  # Configuración por ambiente: llega a la app como variable de entorno y de ahí a /api/info.
  app_settings = {
    AMBIENTE = var.ambiente
  }

  tags = var.etiquetas
}
