# Plan-only tests with mocked Azure providers: no credentials or Azure resources are used.
mock_provider "azurerm" {}
mock_provider "azurerm" {
  alias = "public_dns"
}
mock_provider "azapi" {}

variables {
  env                        = "aat"
  project                    = "test"
  common_tags                = {}
  subscription_id            = "00000000-0000-0000-0000-000000000000"
  resource_group             = "test-rg"
  ssl_mode                   = "FrontDoor"
  certificate_name_check     = true
  log_analytics_workspace_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.OperationalInsights/workspaces/test"
  add_access_policy          = false
  add_access_policy_role     = false
}

run "legacy_disabled_rules_are_unchanged" {
  command = plan
  plan_options {
    target = [azurerm_cdn_frontdoor_firewall_policy.custom]
  }
  variables {
    frontends = [{
      name           = "legacy"
      disabled_rules = { SQLI = ["942450", "942440"], RFI = ["931130"] }
      global_exclusions = [{
        match_variable = "RequestCookieNames"
        operator       = "Equals"
        selector       = "existing_cookie"
      }]
    }]
  }
  assert {
    condition = alltrue(flatten([
      for group in one(azurerm_cdn_frontdoor_firewall_policy.custom["legacy"].managed_rule).override : [
        for rule in group.rule : !rule.enabled && rule.action == "Block" && length(rule.exclusion) == 0
      ]
    ])) && length(one(azurerm_cdn_frontdoor_firewall_policy.custom["legacy"].managed_rule).override) == 2
    error_message = "Existing disabled rules must remain disabled with no new exclusions."
  }
  assert {
    condition = [for rule in one([
      for group in one(azurerm_cdn_frontdoor_firewall_policy.custom["legacy"].managed_rule).override : group if group.rule_group_name == "SQLI"
    ]).rule : rule.rule_id] == ["942450", "942440"]
    error_message = "Preserve disabled-rule order, including groups with unequal list lengths."
  }
  assert {
    condition     = one(one(azurerm_cdn_frontdoor_firewall_policy.custom["legacy"].managed_rule).exclusion).selector == "existing_cookie"
    error_message = "Existing ruleset-wide exclusions must be preserved."
  }
}

run "scoped_exclusions_keep_rules_enabled_and_merge_groups" {
  command = plan
  plan_options {
    target = [azurerm_cdn_frontdoor_firewall_policy.custom]
  }
  variables {
    frontends = [{
      name           = "scoped"
      disabled_rules = { SQLI = ["942450"], RFI = ["931130"] }
      rule_exclusions = {
        SQLI = {
          "942440" = [
            { match_variable = "RequestCookieNames", operator = "Equals", selector = "pcs_session" },
            { match_variable = "QueryStringArgNames", operator = "Equals", selector = "code" }
          ]
        }
      }
    }]
  }
  assert {
    condition = length(one(azurerm_cdn_frontdoor_firewall_policy.custom["scoped"].managed_rule).override) == 2 && length([
      for group in one(azurerm_cdn_frontdoor_firewall_policy.custom["scoped"].managed_rule).override : group if group.rule_group_name == "SQLI"
    ]) == 1 && length(one(azurerm_cdn_frontdoor_firewall_policy.custom["scoped"].managed_rule).exclusion) == 0
    error_message = "Emit one override per group without adding ruleset-wide exclusions."
  }
  assert {
    condition = toset([
      for rule in one([
        for group in one(azurerm_cdn_frontdoor_firewall_policy.custom["scoped"].managed_rule).override : group if group.rule_group_name == "SQLI"
      ]).rule : rule.rule_id
    ]) == toset(["942440", "942450"])
    error_message = "Both the excluded rule and the previously disabled rule must be present."
  }
  assert {
    condition = alltrue(flatten([
      for group in one(azurerm_cdn_frontdoor_firewall_policy.custom["scoped"].managed_rule).override : [
        for rule in group.rule : rule.rule_id != "942440" || (rule.enabled && rule.action == "Block" && toset([
          for exclusion in rule.exclusion : "${exclusion.match_variable}:${exclusion.operator}:${exclusion.selector}"
        ]) == toset(["RequestCookieNames:Equals:pcs_session", "QueryStringArgNames:Equals:code"]))
      ]
    ]))
    error_message = "Only the exact cookie and query parameter values should be excluded from the enabled rule."
  }
}

run "managed_ruleset_preserves_action_and_disabled_precedence" {
  command = plan
  plan_options {
    target = [azurerm_cdn_frontdoor_firewall_policy.custom]
  }
  variables {
    frontends = [{
      name = "managed"
      managed_rulesets = [{
        type           = "Microsoft_DefaultRuleSet"
        version        = "2.1"
        action         = "Log"
        disabled_rules = { SQLI = ["942440"] }
        rule_exclusions = {
          SQLI = {
            "942440" = [{ match_variable = "RequestCookieNames", operator = "Equals", selector = "pcs_session" }]
            "942450" = [{ match_variable = "QueryStringArgNames", operator = "Equals", selector = "code" }]
          }
        }
      }]
    }]
  }
  assert {
    condition = alltrue(flatten([
      for group in one(azurerm_cdn_frontdoor_firewall_policy.custom["managed"].managed_rule).override : [
        for rule in group.rule : rule.rule_id == "942440" ? !rule.enabled && rule.action == "Block" : rule.enabled && rule.action == "Log"
      ]
    ]))
    error_message = "Explicitly disabled rules stay disabled; enabled rules retain the ruleset action."
  }
}

run "frontend_without_overrides_remains_unchanged" {
  command = plan
  plan_options {
    target = [azurerm_cdn_frontdoor_firewall_policy.custom]
  }
  variables {
    frontends = [{ name = "plain" }]
  }
  assert {
    condition = (
      length(one(azurerm_cdn_frontdoor_firewall_policy.custom["plain"].managed_rule).override) == 0 &&
      length(one(azurerm_cdn_frontdoor_firewall_policy.custom["plain"].managed_rule).exclusion) == 0 &&
      one(azurerm_cdn_frontdoor_firewall_policy.custom["plain"].managed_rule).action == "Block"
    )
    error_message = "Frontends without either map must not gain overrides or exclusions."
  }
}
