variable "nombre" {
  description = "Nombre de la Web App (único globalmente: forma parte de la URL)."
  type        = string
}

variable "ambiente" {
  description = "Ambiente (dev o prod). Se expone a la app como AMBIENTE."
  type        = string
}

variable "grupo_recursos" {
  description = "Grupo de recursos donde se crean el plan y la app."
  type        = string
}

variable "ubicacion" {
  description = "Región de Azure."
  type        = string
}

variable "sku_plan" {
  description = "SKU del plan de App Service (B1, S1, P0v3...)."
  type        = string
}

variable "siempre_activa" {
  description = "Mantiene la app cargada aunque no haya tráfico (no disponible en F1)."
  type        = bool
}

variable "version_dotnet" {
  description = "Versión de .NET del runtime (por ejemplo, 10.0)."
  type        = string
}

variable "etiquetas" {
  description = "Etiquetas para los recursos."
  type        = map(string)
}
