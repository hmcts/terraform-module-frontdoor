terraform {
  required_providers {
    azurerm = {
      source                = "hashicorp/azurerm"
      version               = ">= 2.41.0"
      configuration_aliases = [azurerm.data]
    }
  }
}
