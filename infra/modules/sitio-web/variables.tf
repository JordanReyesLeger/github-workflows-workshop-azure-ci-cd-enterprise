variable "nombre_cuenta" {
  description = "Nombre de la cuenta de almacenamiento (3-24 caracteres, minúsculas y números)."
  type        = string
}

variable "grupo_recursos" {
  description = "Grupo de recursos donde se crea la cuenta."
  type        = string
}

variable "ubicacion" {
  description = "Región de Azure."
  type        = string
}

variable "replicacion" {
  description = "Tipo de replicación (LRS, GRS, ZRS...)."
  type        = string
}

variable "dias_retencion_borrado" {
  description = "Días de soft delete para blobs y contenedores."
  type        = number
}

variable "habilitar_versionado" {
  description = "Activa el versionado de blobs."
  type        = bool
}

variable "etiquetas" {
  description = "Etiquetas para los recursos."
  type        = map(string)
}
