resource "azurerm_cdn_frontdoor_firewall_policy" "custom" {
  for_each = { for frontend in var.frontends : frontend.name => frontend
    if lookup(frontend, "redirect", null) == null && lookup(frontend, "enable_managed_ruleset", null) == null
  }
  name                       = "${replace(lookup(each.value, "name"), "-", "")}${replace(var.env, "-", "")}${replace(azurerm_cdn_frontdoor_profile.front_door.sku_name, "_AzureFrontDoor", "")}"
  resource_group_name        = var.resource_group
  sku_name                   = azurerm_cdn_frontdoor_profile.front_door.sku_name
  enabled                    = true
  mode                       = lookup(each.value, "mode", "Prevention")
  redirect_url               = lookup(each.value, "redirect_url", null)
  tags                       = var.common_tags
  custom_block_response_body = lookup(each.value, "response_body", null)

  dynamic "managed_rule" {
    # If managed_rulesets is defined, use it. Otherwise, create a single ruleset from legacy fields
    for_each = try(
      # New format - normalize field names
      [for ruleset in each.value.managed_rulesets : {
        type                  = lookup(ruleset, "type", lookup(ruleset, "ruleset_type", "DefaultRuleSet"))
        version               = lookup(ruleset, "version", lookup(ruleset, "ruleset_value", "1.0"))
        action                = lookup(ruleset, "action", "Block")
        disabled_rules_action = lookup(ruleset, "disabled_rules_action", "Block")
        disabled_rules        = lookup(ruleset, "disabled_rules", {})
        rule_exclusions       = lookup(ruleset, "rule_exclusions", {})
        exclusions            = lookup(ruleset, "exclusions", lookup(ruleset, "global_exclusions", []))
      }],
      # Old format - use legacy fields
      [
        {
          type                  = lookup(each.value, "ruleset_type", "DefaultRuleSet")
          version               = lookup(each.value, "ruleset_value", "1.0")
          action                = "Block"
          disabled_rules_action = lookup(each.value, "disabled_rules_action", "Block")
          disabled_rules        = lookup(each.value, "disabled_rules", {})
          rule_exclusions       = lookup(each.value, "rule_exclusions", {})
          exclusions            = lookup(each.value, "global_exclusions", [])
        }
      ]
    )

    content {
      type    = managed_rule.value.type
      version = managed_rule.value.version
      action  = lookup(managed_rule.value, "action", "Block")

      dynamic "exclusion" {
        for_each = lookup(managed_rule.value, "exclusions", [])
        content {
          match_variable = exclusion.value.match_variable
          operator       = exclusion.value.operator
          selector       = exclusion.value.selector
        }
      }

      dynamic "override" {
        # Emit one override per group, including when it has both disabled rules and exclusions.
        for_each = setunion(keys(managed_rule.value.disabled_rules), keys(managed_rule.value.rule_exclusions))
        content {
          rule_group_name = override.value
          dynamic "rule" {
            # Keep existing disabled-rule order; append only new rule IDs.
            for_each = distinct(concat(
              lookup(managed_rule.value.disabled_rules, override.value, []),
              keys(lookup(managed_rule.value.rule_exclusions, override.value, {}))
            ))
            content {
              rule_id = rule.value
              enabled = !contains(lookup(managed_rule.value.disabled_rules, override.value, []), rule.value)
              action = contains(lookup(managed_rule.value.disabled_rules, override.value, []), rule.value) ? (
                managed_rule.value.disabled_rules_action
              ) : managed_rule.value.action

              dynamic "exclusion" {
                for_each = lookup(lookup(managed_rule.value.rule_exclusions, override.value, {}), rule.value, [])
                content {
                  match_variable = exclusion.value.match_variable
                  operator       = exclusion.value.operator
                  selector       = exclusion.value.selector
                }
              }
            }
          }
        }
      }


    }
  }

  dynamic "custom_rule" {
    iterator = custom_rule
    for_each = lookup(each.value, "custom_rules", [])
    content {
      name                           = custom_rule.value.name
      enabled                        = true
      priority                       = custom_rule.value.priority
      type                           = custom_rule.value.type
      action                         = custom_rule.value.action
      rate_limit_duration_in_minutes = lookup(custom_rule.value, "rate_limit_duration_in_minutes", null)
      rate_limit_threshold           = lookup(custom_rule.value, "rate_limit_threshold", null)

      dynamic "match_condition" {
        iterator = match_condition
        for_each = lookup(custom_rule.value, "match_conditions", [])
        content {
          match_variable     = match_condition.value.match_variable
          operator           = match_condition.value.operator
          negation_condition = match_condition.value.negation_condition
          match_values       = match_condition.value.match_values
          transforms         = can(match_condition.value.transforms) ? match_condition.value.transforms : null
          selector           = match_condition.value.match_variable == "PostArgs" || match_condition.value.match_variable == "RequestHeader" ? match_condition.value.selector : null
        }
      }
    }
  }
}


resource "azurerm_cdn_frontdoor_security_policy" "security_policy" {
  for_each = { for frontend in var.frontends : frontend.name => frontend
    if lookup(frontend, "redirect", null) == null && lookup(frontend, "enable_managed_ruleset", null) == null
  }
  name                     = "${replace(lookup(each.value, "name"), "-", "")}${replace(var.env, "-", "")}${replace(azurerm_cdn_frontdoor_profile.front_door.sku_name, "_AzureFrontDoor", "")}-securityPolicy"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.front_door.id

  security_policies {
    firewall {
      cdn_frontdoor_firewall_policy_id = azurerm_cdn_frontdoor_firewall_policy.custom[each.key].id

      association {
        domain {
          cdn_frontdoor_domain_id = azurerm_cdn_frontdoor_custom_domain.custom_domain[each.key].id
        }
        patterns_to_match = ["/*"]
      }
    }
  }
}
resource "azurerm_cdn_frontdoor_firewall_policy" "default_waf_policy" {
  for_each = { for frontend in var.frontends : frontend.name => frontend
    if lookup(frontend, "enable_managed_ruleset", false)
  }
  name                       = "${replace(lookup(each.value, "name"), "-", "")}${replace(var.env, "-", "")}${replace(azurerm_cdn_frontdoor_profile.front_door.sku_name, "_AzureFrontDoor", "")}"
  resource_group_name        = var.resource_group
  sku_name                   = azurerm_cdn_frontdoor_profile.front_door.sku_name
  enabled                    = true
  mode                       = lookup(each.value, "mode", "Prevention")
  redirect_url               = lookup(each.value, "redirect_url", null)
  tags                       = var.common_tags
  custom_block_response_body = lookup(each.value, "response_body", null)
}

resource "azurerm_cdn_frontdoor_security_policy" "default_security_policy" {
  for_each = { for frontend in var.frontends : frontend.name => frontend
    if lookup(frontend, "enable_managed_ruleset", false)
  }
  name                     = "${replace(lookup(each.value, "name"), "-", "")}${replace(var.env, "-", "")}${replace(azurerm_cdn_frontdoor_profile.front_door.sku_name, "_AzureFrontDoor", "")}-securityPolicy"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.front_door.id

  security_policies {
    firewall {
      cdn_frontdoor_firewall_policy_id = azurerm_cdn_frontdoor_firewall_policy.default_waf_policy[each.key].id

      association {
        domain {
          cdn_frontdoor_domain_id = azurerm_cdn_frontdoor_custom_domain.custom_domain[each.key].id
        }
        patterns_to_match = ["/*"]
      }
    }
  }
}
