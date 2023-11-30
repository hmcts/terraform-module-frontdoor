# KeyVault for the certificate must be in the same subscription as Frontdoor.
data "azurerm_key_vault" "certificate_vault" {
  count               = var.add_access_policy == true ? 1 : 0
  name                = var.certificate_key_vault_name
  resource_group_name = var.key_vault_resource_group
}
moved {
  from = data.azurerm_key_vault.certificate_vault
  to   = data.azurerm_key_vault.certificate_vault[0]
}
data "azurerm_key_vault_secret" "certificate" {
  for_each = { for frontend in var.frontends :
    frontend.name => frontend
    if lookup(frontend, "ssl_mode", var.ssl_mode) == "AzureKeyVault"
  }
  name         = lookup(each.value, "certificate_name")
  key_vault_id = data.azurerm_key_vault.certificate_vault[0].id
}

data "azurerm_key_vault_certificate" "certificate" {
  for_each = { for frontend in var.frontends :
    frontend.name => frontend
    if lookup(frontend, "ssl_mode", var.ssl_mode) == "AzureKeyVault"
  }
  name         = lookup(each.value, "certificate_name")
  key_vault_id = data.azurerm_key_vault.certificate_vault[0].id
}

data "azurerm_client_config" "current" {}
