terraform {
  required_version = ">= 1.9.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.8"
    }
  }

  # Configuración parcial: el pipeline (y `terraform init` local) pasan el resto con
  # -backend-config. Así el código no lleva nombres de cuentas ni suscripciones.
  backend "azurerm" {
    use_azuread_auth = true
  }
}

provider "azurerm" {
  features {}

  subscription_id     = var.suscripcion_id
  storage_use_azuread = true
  # Autenticación: ARM_USE_OIDC / ARM_CLIENT_ID / ARM_TENANT_ID las pone el workflow.
  # En tu máquina, `az login` es suficiente.
}
