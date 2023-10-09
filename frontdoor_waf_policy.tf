resource "azurerm_cdn_frontdoor_firewall_policy" "custom" {
  for_each = { for frontend in var.frontends : frontend.name => frontend
    if lookup(frontend, "redirect", null) == null
  }
  name                = "${replace(lookup(each.value, "name"), "-", "")}${replace(var.env, "-", "")}${replace(azurerm_cdn_frontdoor_profile.front_door.sku_name, "_AzureFrontDoor", "")}"
  resource_group_name = var.resource_group
  sku_name            = azurerm_cdn_frontdoor_profile.front_door.sku_name
  enabled             = true
  mode                = lookup(each.value, "mode", "Prevention")
  tags                = var.common_tags

  managed_rule {
    type    = "DefaultRuleSet"
    version = "1.0"
    action  = "Block"

    dynamic "exclusion" {
      iterator = exclusion
      for_each = lookup(each.value, "global_exclusions", [])

      content {
        match_variable = exclusion.value.match_variable
        operator       = exclusion.value.operator
        selector       = exclusion.value.selector
      }
    }

    dynamic "override" {
      iterator = rulesets
      for_each = lookup(each.value, "disabled_rules", {})

      content {
        rule_group_name = rulesets.key

        dynamic "rule" {
          iterator = rule_id
          for_each = rulesets.value

          content {
            rule_id = rule_id.value
            enabled = false
            action  = "Block"
          }
        }
      }
    }
  }
  dynamic "custom_rule" {
    iterator = custom_rule
    for_each = lookup(each.value, "custom_rules", [])
    content {
      name     = custom_rule.value.name
      enabled  = true
      priority = custom_rule.value.priority
      type     = custom_rule.value.type
      action   = custom_rule.value.action

      dynamic "match_condition" {
        iterator = match_condition
        for_each = lookup(custom_rule.value, "match_conditions", [])
        content {
          match_variable     = match_condition.value.match_variable
          operator           = match_condition.value.operator
          negation_condition = match_condition.value.negation_condition
          match_values       = match_condition.value.match_values
          transforms         = can(match_condition.value.transforms) ? match_condition.value.transforms : null
        }
      }
    }
  }
}


resource "azurerm_cdn_frontdoor_security_policy" "security_policy" {
  for_each                 = { for frontend in var.frontends : frontend.name => frontend }
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

resource "azurerm_cdn_frontdoor_rule_set" "https_redirect" {
  name                     = "httpsredirect"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.front_door.id
}

resource "azurerm_cdn_frontdoor_rule" "https_redirect_rules" {
  depends_on = [azurerm_cdn_frontdoor_origin_group.defaultBackend, azurerm_cdn_frontdoor_origin.defaultBackend_origin]

  name                      = "httpsredirectrule"
  cdn_frontdoor_rule_set_id = azurerm_cdn_frontdoor_rule_set.https_redirect.id
  order                     = 1
  behavior_on_match         = "Continue"

  actions {
    url_redirect_action {
      redirect_type        = "Moved"
      destination_hostname = ""
      redirect_protocol    = "Https"
    }
  }
}

resource "azurerm_cdn_frontdoor_rule_set" "redirect_hostname_rule_set" {
  name                     = "hostnameredirectruleset"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.front_door.id
}

resource "azurerm_cdn_frontdoor_rule" "redirect_hostname" {
  for_each = {
    for frontend in var.frontends : frontend.name => frontend
    if lookup(frontend, "redirect", null) != null
  }
  name = "${each.value.name}redirectrule"

  cdn_frontdoor_rule_set_id = azurerm_cdn_frontdoor_rule_set.redirect_hostname_rule_set.id
  order                     = 1
  behavior_on_match         = "Continue"

  actions {
    url_redirect_action {
      redirect_type        = "Moved"
      redirect_protocol    = "Https"
      destination_hostname = each.value.redirect
    }
  }

  depends_on = [azurerm_cdn_frontdoor_origin_group.defaultBackend, azurerm_cdn_frontdoor_origin.defaultBackend_origin]
}

resource "azurerm_cdn_frontdoor_rule_set" "www_redirect_rule_set" {
  name                     = "wwwredirectruleset"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.front_door.id
}

resource "azurerm_cdn_frontdoor_rule" "redirect_www" {
  for_each = {
    for frontend in var.frontends : frontend.name => frontend
    if lookup(frontend, "www_redirect", false)
  }
  name = "${each.value.name}wwwredirectrule"

  cdn_frontdoor_rule_set_id = azurerm_cdn_frontdoor_rule_set.www_redirect_rule_set.id
  order                     = 1
  behavior_on_match         = "Continue"

  actions {
    url_redirect_action {
      redirect_type        = "Moved"
      redirect_protocol    = "Https"
      destination_hostname = each.value.custom_domain
    }
  }

  depends_on = [azurerm_cdn_frontdoor_origin_group.defaultBackend, azurerm_cdn_frontdoor_origin.defaultBackend_origin]
}
