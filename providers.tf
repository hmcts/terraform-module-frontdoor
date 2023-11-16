terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.34.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "~> 1.0"
    }
  }
}

# provider "azurerm" {
#   alias = "public_dns"

#   features {}
#   subscription_id = local.dns_zone_subscription
# }
