module "landing_zone" {
  source = "git::https://github.com/hmcts/terraform-module-frontdoor.git?ref=features/dtspo75_1"

  providers = {
    azurerm      = azurerm
    azurerm.data = azurerm.data
  }

  common_tags                = var.common_tags
  env                        = var.env
  subscription               = var.subscription
  project                    = var.project
  location                   = var.location
  frontends                  = var.frontends
  enable_ssl                 = var.enable_ssl
  ssl_mode                   = var.ssl_mode
  resource_group             = var.resource_group
  subscription_id            = var.subscription_id
  certificate_key_vault_name = var.certificate_key_vault_name
  oms_env                    = var.oms_env
  certificate_name_check     = var.certificate_name_check
  key_vault_resource_group   = var.key_vault_resource_group
}

