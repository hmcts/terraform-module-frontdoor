terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.34.0"
      configuration_aliases = [ azurerm.public_dns, azapi.frontdoor_azapi ]
    }
  }
}