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

resource "azurerm_cdn_frontdoor_rule_set" "caching_ruleset" {
  for_each = {
    for frontend in var.frontends : frontend.name => frontend
    if lookup(frontend, "cache_enabled", "true") == "true"
  }
  name                     = replace("${each.value.name}caching", "-", "")
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.front_door.id
}

resource "azurerm_cdn_frontdoor_rule" "caching_rule" {
  for_each = {
    for frontend in var.frontends : frontend.name => frontend
    if lookup(frontend, "cache_enabled", "true") == "true"
  }
  name = replace("${each.value.name}cachingrule", "-", "")

  cdn_frontdoor_rule_set_id = azurerm_cdn_frontdoor_rule_set.caching_ruleset[each.key].id
  order                     = 3

  conditions {
    dynamic "url_file_extension_condition" {
      for_each = lookup(each.value, "caching", {
        url_file_extension_conditions = [
          {
            operator         = "Equal"
            negate_condition = false
            match_values     = ["jpg", "png", "css", "ico", "js"]
            transforms       = ["Lowercase"]
          }
        ]
      }).url_file_extension_conditions
      iterator = condition
      content {
        operator         = lookup(condition.value, "operator", null) != null ? condition.value.operator : "Equal"
        negate_condition = lookup(condition.value, "negate_condition", null) != null ? condition.value.negate_condition : false
        match_values     = lookup(condition.value, "match_values", null) != null ? condition.value.match_values : ["jpg", "png", "css", "ico", "js"]
        transforms       = lookup(condition.value, "transforms", null) != null ? condition.value.transforms : ["Lowercase"]
      }
    }
  }
  actions {
    dynamic "route_configuration_override_action" {
      for_each = lookup(each.value, "caching", {
        route_configuration_override_action = [
          {
            cache_duration                = null
            cdn_frontdoor_origin_group_id = null
            forwarding_protocol           = null
            query_string_caching_behavior = "UseQueryString"
            query_string_parameters       = null
            compression_enabled           = false
            cache_behavior                = "HonorOrigin"
          }
        ]
      }).route_configuration_override_action
      iterator = action
      content {
        cache_duration                = lookup(action.value, "cache_duration", null) != null ? action.value.cache_duration : null
        cdn_frontdoor_origin_group_id = lookup(action.value, "cdn_frontdoor_origin_group_id", null) != null ? action.value.cdn_frontdoor_origin_group_id : null
        forwarding_protocol           = lookup(action.value, "forwarding_protocol", null) != null ? action.value.forwarding_protocol : null
        query_string_caching_behavior = lookup(action.value, "query_string_caching_behavior", null) != null ? action.value.query_string_caching_behavior : "UseQueryString"
        query_string_parameters       = lookup(action.value, "query_string_parameters", null) != null ? action.value.query_string_parameters : null
        compression_enabled           = lookup(action.value, "compression_enabled", null) != null ? action.value.compression_enabled : false
        cache_behavior                = lookup(action.value, "cache_behavior", null) != null ? action.value.cache_behavior : "HonorOrigin"
      }
    }
  }

  depends_on = [azurerm_cdn_frontdoor_origin_group.defaultBackend, azurerm_cdn_frontdoor_origin.defaultBackend_origin]
}

resource "azurerm_cdn_frontdoor_rule_set" "hsts_rules" {
  for_each = {
    for frontend in var.frontends : frontend.name => frontend
    if lookup(frontend, "hsts_header_enabled", "false") == "true"
  }
  name                     = replace("${each.value.name}HstsRule", "-", "")
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.front_door.id
}

resource "azurerm_cdn_frontdoor_rule" "hsts_header" {
  for_each = {
    for frontend in var.frontends : frontend.name => frontend
    if lookup(frontend, "hsts_header_enabled", "false") == "true"
  }

  name                      = replace("${each.value.name}HstsHeader", "-", "")
  cdn_frontdoor_rule_set_id = azurerm_cdn_frontdoor_rule_set.hsts_rules[each.key].id
  order                     = 1

  actions {
    response_header_action {
      header_action = "Overwrite"
      header_name   = "Strict-Transport-Security"
      value         = "max-age=31536000; includeSubDomains"
    }
  }
}

locals {
  # Flatten rule sets per frontend into a list of items with stable keys
  custom_rulesets = flatten([
    for fe_key, rs_collection in var.rule_sets : (
      # Support both list and map inputs for per-frontend rule sets
      can(length(rs_collection)) ? [
        for idx, rs in rs_collection : {
          fe_key = fe_key
          rs_key = tostring(idx)
          name   = lookup(rs, "name", tostring(idx))
          rs     = rs
          id_key = "${fe_key}-${lookup(rs, "name", tostring(idx))}"
        }
      ] : []
    )
  ])

  # Flatten rules across all per-frontend rule sets
  custom_rules_flat = flatten([
    for item in local.custom_rulesets : [
      for r in lookup(item.rs, "rules", []) : {
        id_key     = "${item.id_key}-${replace(r.name, " ", "")}"
        rs_id_key  = item.id_key
        rule       = r
      }
    ]
  ])

  # Convenience map to resolve origin group IDs by key for override actions
  origin_group_ids = merge(
    {
      defaultBackend = azurerm_cdn_frontdoor_origin_group.defaultBackend.id
    },
    { for k, v in azurerm_cdn_frontdoor_origin_group.origin_group : k => v.id }
  )
}

resource "azurerm_cdn_frontdoor_rule_set" "custom" {
  for_each                 = { for item in local.custom_rulesets : item.id_key => item }
  name                     = replace("${each.value.fe_key}${each.value.name}", "-", "")
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.front_door.id
}

resource "azurerm_cdn_frontdoor_rule" "custom" {
  for_each = { for item in local.custom_rules_flat : item.id_key => item }

  name                      = replace(each.value.rule.name, "-", "")
  cdn_frontdoor_rule_set_id = azurerm_cdn_frontdoor_rule_set.custom[each.value.rs_id_key].id
  order                     = lookup(each.value.rule, "order", 1)
  behavior_on_match         = lookup(each.value.rule, "behavior_on_match", null)

  dynamic "conditions" {
    for_each = [lookup(each.value.rule, "conditions", {})]
    content {
      dynamic "url_path_condition" {
        for_each = lookup(conditions.value, "url_path_conditions", [])
        iterator = c
        content {
          operator         = lookup(c.value, "operator", "Equal")
          negate_condition = lookup(c.value, "negate_condition", false)
          match_values     = lookup(c.value, "match_values", null)
          transforms       = lookup(c.value, "transforms", null)
        }
      }
      dynamic "url_file_extension_condition" {
        for_each = lookup(conditions.value, "url_file_extension_conditions", [])
        iterator = c
        content {
          operator         = lookup(c.value, "operator", "Equal")
          negate_condition = lookup(c.value, "negate_condition", false)
          match_values     = lookup(c.value, "match_values", null)
          transforms       = lookup(c.value, "transforms", null)
        }
      }
      dynamic "request_header_condition" {
        for_each = lookup(conditions.value, "request_header_conditions", [])
        iterator = c
        content {
          header_name      = lookup(c.value, "header_name", lookup(c.value, "selector", null))
          operator         = lookup(c.value, "operator", "Equal")
          negate_condition = lookup(c.value, "negate_condition", false)
          match_values     = lookup(c.value, "match_values", null)
          transforms       = lookup(c.value, "transforms", null)
        }
      }
      dynamic "request_method_condition" {
        for_each = lookup(conditions.value, "request_method_conditions", [])
        iterator = c
        content {
          operator         = lookup(c.value, "operator", "Equal")
          negate_condition = lookup(c.value, "negate_condition", false)
          match_values     = lookup(c.value, "match_values", null)
        }
      }
      dynamic "query_string_condition" {
        for_each = lookup(conditions.value, "query_string_conditions", [])
        iterator = c
        content {
          operator         = lookup(c.value, "operator", "Equal")
          negate_condition = lookup(c.value, "negate_condition", false)
          match_values     = lookup(c.value, "match_values", null)
          transforms       = lookup(c.value, "transforms", null)
        }
      }
      dynamic "cookies_condition" {
        for_each = lookup(conditions.value, "cookies_conditions", [])
        iterator = c
        content {
          cookie_name      = lookup(c.value, "cookie_name", lookup(c.value, "selector", null))
          operator         = lookup(c.value, "operator", "Equal")
          negate_condition = lookup(c.value, "negate_condition", false)
          match_values     = lookup(c.value, "match_values", null)
          transforms       = lookup(c.value, "transforms", null)
        }
      }
    }
  }

  dynamic "actions" {
    for_each = [lookup(each.value.rule, "actions", {})]
    content {
      dynamic "response_header_action" {
        for_each = lookup(actions.value, "response_header_actions", [])
        iterator = a
        content {
          header_action = lookup(a.value, "header_action", "Overwrite")
          header_name   = a.value.header_name
          value         = a.value.value
        }
      }
      dynamic "url_redirect_action" {
        for_each = lookup(actions.value, "url_redirect_actions", [])
        iterator = a
        content {
          redirect_type        = lookup(a.value, "redirect_type", "Moved")
          destination_hostname = lookup(a.value, "destination_hostname", null)
          redirect_protocol    = lookup(a.value, "redirect_protocol", null)
          destination_path     = lookup(a.value, "destination_path", null)
          query_string         = lookup(a.value, "query_string", null)
          destination_fragment = lookup(a.value, "destination_fragment", null)
        }
      }
      dynamic "route_configuration_override_action" {
        for_each = lookup(actions.value, "route_configuration_override_actions", [])
        iterator = a
        content {
          cache_duration = lookup(a.value, "cache_duration", null)
          # Prefer explicit ID if provided; otherwise allow using a convenience key to refer to a module-managed origin group
          cdn_frontdoor_origin_group_id = coalesce(
            lookup(a.value, "cdn_frontdoor_origin_group_id", null),
            lookup(local.origin_group_ids, lookup(a.value, "cdn_frontdoor_origin_group_key", ""), null)
          )
          forwarding_protocol           = lookup(a.value, "forwarding_protocol", null)
          query_string_caching_behavior = lookup(a.value, "query_string_caching_behavior", null)
          query_string_parameters       = lookup(a.value, "query_string_parameters", null)
          compression_enabled           = lookup(a.value, "compression_enabled", null)
          cache_behavior                = lookup(a.value, "cache_behavior", null)
        }
      }
      dynamic "url_rewrite_action" {
        for_each = lookup(actions.value, "url_rewrite_actions", [])
        iterator = a
        content {
          source_pattern          = lookup(a.value, "source_pattern", null)
          destination             = lookup(a.value, "destination", null)
          preserve_unmatched_path = lookup(a.value, "preserve_unmatched_path", null)
        }
      }
    }
  }

  depends_on = [azurerm_cdn_frontdoor_origin_group.defaultBackend, azurerm_cdn_frontdoor_origin.defaultBackend_origin]
}
