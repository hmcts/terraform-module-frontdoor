module "log_analytics_workspace" {
  source      = "git::https://github.com/hmcts/terraform-module-log-analytics-workspace-id.git?ref=master"
  environment = var.env
}

data "azurerm_client_config" "this" {}

module "tags" {
  source      = "git::https://github.com/hmcts/terraform-module-common-tags.git?ref=master"
  environment = var.env
  product     = "cft-platform"
  builtFrom   = "local"
}

module "landing_zone" {
  source = "../"

  common_tags                = module.tags.common_tags
  env                        = var.env
  project                    = var.project
  location                   = var.location
  frontends                  = var.frontends
  ssl_mode                   = var.ssl_mode
  resource_group             = var.resource_group
  subscription_id            = data.azurerm_client_config.this.subscription_id
  certificate_key_vault_name = var.certificate_key_vault_name
  oms_env                    = var.oms_env
  certificate_name_check     = var.certificate_name_check
  key_vault_resource_group   = var.key_vault_resource_group
  log_analytics_workspace_id = module.log_analytics_workspace.workspace_id

  add_access_policy      = false
  add_access_policy_role = false
}

