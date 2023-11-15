resource "azurerm_key_vault_access_policy" "frontdoor_premium_kv_access" {
  for_each = { for frontend in var.frontends :
    frontend.name => frontend
    if lookup(frontend, "ssl_mode", var.ssl_mode) == "AzureKeyVault"
  }
  key_vault_id = data.azurerm_key_vault.certificate_vault[each.key].id

  object_id               = jsondecode(azapi_update_resource.frontdoor_system_identity.output).identity.principalId
  tenant_id               = jsondecode(azapi_update_resource.frontdoor_system_identity.output).identity.tenantId
  secret_permissions      = ["Get", "List"]
  certificate_permissions = ["Get", "List"]
  key_permissions         = ["Get", "List"]
}

resource "azurerm_role_assignment" "frontdoor_premium_kv_access" {
  for_each = { for frontend in var.frontends :
    frontend.name => frontend
    if lookup(frontend, "ssl_mode", var.ssl_mode) == "AzureKeyVault"
  }

  role_definition_name = "Key Vault Secrets User"
  principal_id         = jsondecode(azapi_update_resource.frontdoor_system_identity.output).identity.principalId
  scope                = data.azurerm_key_vault.certificate_vault[each.key].id
}
