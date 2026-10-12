variable "suscripcion_id" {
  description = "Id de la suscripción de Azure donde se despliega."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$", var.suscripcion_id))
    error_message = "suscripcion_id debe ser un GUID."
  }
}

variable "nombre_app" {
  description = "Nombre corto de la aplicación. Va en los nombres de los recursos."
  type        = string
  default     = "contosobiker"

  validation {
    condition     = can(regex("^[a-z0-9]{3,12}$", var.nombre_app))
    error_message = "nombre_app: de 3 a 12 caracteres, solo minúsculas y números."
  }
}

variable "ambiente" {
  description = "Ambiente que se despliega."
  type        = string

  validation {
    condition     = contains(["dev", "prod"], var.ambiente)
    error_message = "ambiente debe ser dev o prod."
  }
}

variable "ubicacion" {
  description = "Región de Azure."
  type        = string
  default     = "centralus"
}

variable "sku_plan" {
  description = "SKU del plan de App Service (B1, S1, P0v3...)."
  type        = string
  default     = "B1"
}

variable "siempre_activa" {
  description = "Mantiene la app cargada aunque no haya tráfico."
  type        = bool
  default     = true
}

variable "version_dotnet" {
  description = "Versión de .NET del runtime de la Web App."
  type        = string
  default     = "10.0"
}
variable "etiquetas_extra" {
  description = "Etiquetas adicionales para todos los recursos."
  type        = map(string)
  default     = {}
}
