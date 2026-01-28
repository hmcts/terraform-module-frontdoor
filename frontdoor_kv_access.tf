resource "azurerm_key_vault_access_policy" "frontdoor_premium_kv_access" {
  count        = var.add_access_policy == true ? 1 : 0
  key_vault_id = data.azurerm_key_vault.certificate_vault[0].id

  object_id               = azurerm_cdn_frontdoor_profile.front_door.identity[0].principal_id
  tenant_id               = azurerm_cdn_frontdoor_profile.front_door.identity[0].tenant_id
  secret_permissions      = ["Get", "List"]
  certificate_permissions = ["Get", "List"]
  key_permissions         = ["Get", "List"]
}

resource "azurerm_role_assignment" "frontdoor_premium_kv_access" {
  count = var.add_access_policy_role == true ? 1 : 0

  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_cdn_frontdoor_profile.front_door.identity[0].principal_id
  scope                = data.azurerm_key_vault.certificate_vault[0].id
}
