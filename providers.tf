terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "< 6.0.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.3"
    }
  }
}

provider "azurerm" {
  alias = "public_dns"

  features {}
  subscription_id = local.dns_zone_subscription
}
