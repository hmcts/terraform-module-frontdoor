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

resource "azurerm_cdn_frontdoor_rule_set" "cache_static_ruleset" {
  for_each = {
    for frontend in var.frontends : frontend.name => frontend
    if lookup(frontend, "cache_static_files", null) != null
  }
  name                     = replace("${each.value.name}cachestaticfiles", "-", "")
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.front_door.id
}

resource "azurerm_cdn_frontdoor_rule" "cache_static_rule" {
  for_each = {
    for frontend in var.frontends : frontend.name => frontend
    if lookup(frontend, "cache_static_files", null) != null
  }
  name = replace("${each.value.name}cachestaticfilesrule", "-", "")

  cdn_frontdoor_rule_set_id = azurerm_cdn_frontdoor_rule_set.cache_static_ruleset[each.key].id
  order                     = 3

  conditions {
    dynamic "url_file_extension_condition" {
      for_each = each.value.cache_static_files.url_file_extension_conditions
      iterator = condition
      content {
        operator         = lookup(condition.value, "operator", null) != null ? condition.value.operator : "Equal"
        negate_condition = lookup(condition.value, "negate_condition", null) != null ? condition.value.negate_condition : false
        match_values     = lookup(condition.value, "match_values", null) != null ? condition.value.match_values : ["jpg", "png", "css", "ico"]
        transforms       = lookup(condition.value, "transforms", null) != null ? condition.value.transforms : ["Lowercase"]
      }
    }
  }
  actions {
    dynamic "route_configuration_override_action" {
      for_each = each.value.cache_static_files.route_configuration_override_action
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
