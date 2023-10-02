terraform {
  required_providers {
    azurerm = {
      source                = "hashicorp/azurerm"
      version               = ">= 3.34.0"
      configuration_aliases = [azurerm.public_dns]
    }
    azapi = {
      source                = "Azure/azapi"
      version               = "~> 1.0"
      configuration_aliases = [azapi.frontdoor-azapi]
    }
  }
}