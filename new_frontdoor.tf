resource "azurerm_cdn_frontdoor_profile" "my_front_door" {
  name                = "${var.project}-${var.env}"
  resource_group_name = var.resource_group
  sku_name            = var.front_door_sku_name
  tags                = var.common_tags
}

resource "azurerm_cdn_frontdoor_endpoint" "my_endpoint" {
  name                     = "${var.project}-${var.env}"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.my_front_door.id
  tags                     = var.common_tags
}

resource "azurerm_cdn_frontdoor_origin_group" "my_origin_group" {
  for_each                 = { for frontend in var.new_frontends: frontend.name => frontend }
  name                     = each.value.name
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.my_front_door.id
  session_affinity_enabled = false

    load_balancing {
        sample_size                 = 4
        successful_samples_required = 2
        additional_latency_in_milliseconds = 0
    }
    health_probe {
        path                = lookup(each.value, "health_path", "/health/liveness")
        protocol            = lookup(each.value, "health_protocol", "Http")
        interval_in_seconds = 120
    }
}    

resource "azurerm_cdn_frontdoor_origin" "front_door_origin" {
  for_each                      = { for frontend in var.new_frontends: frontend.name => frontend }
  name                          = each.value.name
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.my_origin_group[each.key].id

  enabled                        = true
  host_name                      = each.value.backend_domain[0]
  http_port                      = lookup(each.value, "http_port", 80)
  https_port                     = 443
  origin_host_header             = each.value.custom_domain
  priority                       = 1
  weight                         = 50
  certificate_name_check_enabled = true
}

resource "azurerm_cdn_frontdoor_route" "routing_rule_A" {
   for_each = { 
    for frontend in var.new_frontends: frontend.name => frontend
    if lookup(frontend, "redirect", null) == null
    }
    name                          = each.value.name
    cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.my_endpoint.id
    cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.my_origin_group[each.key].id
    cdn_frontdoor_origin_ids      = [azurerm_cdn_frontdoor_origin.front_door_origin[each.key].id]
    enabled                = true

    supported_protocols    = lookup(each.value, "enable_ssl", true) ? ["Https"] : ["Http"]
    patterns_to_match      = lookup(each.value, "url_patterns", ["/*"])
    forwarding_protocol    = lookup(each.value, "forwarding_protocol", "HttpOnly")
    link_to_default_domain = true
    https_redirect_enabled = false
} 

resource "azurerm_cdn_frontdoor_route" "routing_rule_B" {
   for_each = { 
    for frontend in var.new_frontends: frontend.name => frontend
    if lookup(frontend, "enable_ssl", true) && lookup(frontend, "redirect", null) == null
   }
    name                          = "${each.value.name}HttpsRedirect"
    cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.my_endpoint.id
    cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.my_origin_group[each.key].id
    cdn_frontdoor_origin_ids       = [azurerm_cdn_frontdoor_origin.front_door_origin[each.key].id]
    enabled                = true

    supported_protocols    = ["Http", "Https"]
    patterns_to_match      = ["/*"]
    link_to_default_domain = true
    https_redirect_enabled = true
}

resource "azurerm_cdn_frontdoor_route" "routing_rule_C" {
   for_each = {
      for frontend in var.new_frontends: frontend.name => frontend
      if lookup(frontend, "www_redirect", false)
    } 
    name                          = "${each.value.name}wwwRedirect"
    cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.my_endpoint.id
    cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.my_origin_group[each.key].id
    cdn_frontdoor_origin_ids      = [azurerm_cdn_frontdoor_origin.front_door_origin[each.key].id]
    enabled                = true

    supported_protocols    = ["Http", "Https"]
    patterns_to_match      = ["/*"]
    link_to_default_domain = true
    https_redirect_enabled = true
}

resource "azurerm_cdn_frontdoor_route" "routing_rule_D" {
   for_each = {
      for frontend in var.new_frontends: frontend.name => frontend
      if lookup(frontend, "redirect", null) != null
    }
    name                          = "${each.value.name}redirect"
    cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.my_endpoint.id
    cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.my_origin_group[each.key].id
    cdn_frontdoor_origin_ids      = [azurerm_cdn_frontdoor_origin.front_door_origin[each.key].id]
    enabled                = true

    supported_protocols    = ["Http", "Https"]
    patterns_to_match      = ["/*"]
    link_to_default_domain = true
    https_redirect_enabled = true
}