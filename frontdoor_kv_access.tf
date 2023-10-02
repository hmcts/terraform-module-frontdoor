# resource "azurerm_key_vault_access_policy" "frontdoor_kv_access" {
#   count        = var.add_access_policy == true ? 1 : 0
#   key_vault_id = data.azurerm_key_vault.certificate_vault.id

#   object_id = "0a7e9367-4349-4b24-974a-bfa7b23a38fc"
#   tenant_id = data.azurerm_client_config.current.tenant_id

#   secret_permissions      = ["Get", "List"]
#   certificate_permissions = ["Get", "List"]
#   key_permissions         = ["Get", "List"]
# }

# resource "azurerm_role_assignment" "frontdoor_kv_access" {
#   count = var.add_access_policy_role == true ? 1 : 0

#   role_definition_name = "Key Vault Secrets User"
#   principal_id         = "0a7e9367-4349-4b24-974a-bfa7b23a38fc"
#   scope                = data.azurerm_key_vault.certificate_vault.id
# }

resource "azurerm_key_vault_access_policy" "frontdoor_premium_kv_access" {
  count        = var.add_access_policy == true ? 1 : 0
  key_vault_id = data.azurerm_key_vault.certificate_vault.id

  object_id = jsondecode(azapi_update_resource.frontdoor_system_identity.output).identity.principalId
  tenant_id = jsondecode(azapi_update_resource.frontdoor_system_identity.output).identity.tenantId
  secret_permissions      = ["Get", "List"]
  certificate_permissions = ["Get", "List"]
  key_permissions         = ["Get", "List"]
}

resource "azurerm_role_assignment" "frontdoor_premium_kv_access" {
  count = var.add_access_policy_role == true ? 1 : 0

  role_definition_name = "Key Vault Secrets User"
  principal_id         = jsondecode(azapi_update_resource.frontdoor_system_identity.output).identity.principalId
  scope                = data.azurerm_key_vault.certificate_vault.id
}