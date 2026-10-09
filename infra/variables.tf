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
  default     = "eastus2"
}

variable "replicacion" {
  description = "Tipo de replicación de la cuenta de almacenamiento (LRS, GRS, ZRS...)."
  type        = string
  default     = "LRS"
}

variable "dias_retencion_borrado" {
  description = "Días que se conservan los blobs y contenedores borrados (soft delete)."
  type        = number
  default     = 7
}

variable "habilitar_versionado" {
  description = "Conserva versiones anteriores de cada archivo publicado."
  type        = bool
  default     = false
}

variable "etiquetas_extra" {
  description = "Etiquetas adicionales para todos los recursos."
  type        = map(string)
  default     = {}
}
