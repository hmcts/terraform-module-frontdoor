resource "azurerm_cdn_frontdoor_profile" "front_door" {
  name                = "${var.project}-${var.env}"
  resource_group_name = var.resource_group
  sku_name            = var.front_door_sku_name
  tags                = var.common_tags
}

resource "azapi_update_resource" "frontdoor_system_identity" {
  type        = "Microsoft.Cdn/profiles@2023-02-01-preview"
  resource_id = azurerm_cdn_frontdoor_profile.front_door.id
  body = jsonencode({
    "identity" : {
      "type" : "SystemAssigned"
    }
  })
  response_export_values = ["identity.principalId", "identity.tenantId"]

}


resource "azurerm_cdn_frontdoor_endpoint" "endpoint" {
  name                     = "${var.project}-${var.env}"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.front_door.id
  tags                     = var.common_tags
}
######## Defaults ########
resource "azurerm_cdn_frontdoor_origin_group" "defaultBackend" {
  name                     = "defaultBackend"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.front_door.id
  session_affinity_enabled = false

  load_balancing {
    sample_size                        = 4
    successful_samples_required        = 2
    additional_latency_in_milliseconds = 0
  }
}

resource "azurerm_cdn_frontdoor_origin" "defaultBackend_origin" {
  name                          = "defaultBackend"
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.defaultBackend.id

  enabled                        = true
  host_name                      = "www.bing.com"
  http_port                      = 80
  https_port                     = 443
  origin_host_header             = "www.bing.com"
  priority                       = 1
  weight                         = 50
  certificate_name_check_enabled = true
}

resource "azurerm_cdn_frontdoor_route" "default_routing_rule" {
  name                          = "defaultRouting"
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.endpoint.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.defaultBackend.id
  cdn_frontdoor_origin_ids      = [azurerm_cdn_frontdoor_origin.defaultBackend_origin.id]
  enabled                       = true

  supported_protocols    = ["Http", "Https"]
  patterns_to_match      = ["/*"]
  forwarding_protocol    = "MatchRequest"
  link_to_default_domain = true
  https_redirect_enabled = false
}
######## End defaults ########

resource "azurerm_cdn_frontdoor_origin_group" "origin_group" {
  for_each                 = { for frontend in var.new_frontends : frontend.name => frontend }
  name                     = each.value.name
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.front_door.id
  session_affinity_enabled = false

  load_balancing {
    sample_size                        = 4
    successful_samples_required        = 2
    additional_latency_in_milliseconds = 0
  }

  # There's no point adding a health probe with a single backend, it just adds a lot of traffic for no benefit
  dynamic "health_probe" {
    for_each = length(each.value["backend_domain"]) > 1 ? [1] : []
    content {
      path                = lookup(each.value, "health_path", "/health/liveness")
      protocol            = lookup(each.value, "health_protocol", "Http")
      interval_in_seconds = 120
    }
  }
}

resource "azurerm_cdn_frontdoor_origin" "front_door_origin" {
  for_each                      = { for frontend in var.new_frontends : frontend.name => frontend }
  name                          = each.value.name
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.origin_group[each.key].id

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
    for frontend in var.new_frontends : frontend.name => frontend
    if lookup(frontend, "redirect", null) == null
  }
  name                            = each.value.name
  cdn_frontdoor_endpoint_id       = azurerm_cdn_frontdoor_endpoint.endpoint.id
  cdn_frontdoor_origin_group_id   = azurerm_cdn_frontdoor_origin_group.origin_group[each.key].id
  cdn_frontdoor_origin_ids        = [azurerm_cdn_frontdoor_origin.front_door_origin[each.key].id]
  cdn_frontdoor_custom_domain_ids = [azurerm_cdn_frontdoor_custom_domain.custom_domain[each.key].id]
  enabled                         = true

  cache {
    compression_enabled           = false
    query_string_caching_behavior = "UseQueryString"
  }

  supported_protocols    = lookup(each.value, "enable_ssl", true) ? ["Https"] : ["Http"]
  patterns_to_match      = lookup(each.value, "url_patterns", ["/*"])
  forwarding_protocol    = lookup(each.value, "forwarding_protocol", "HttpOnly")
  link_to_default_domain = false
  https_redirect_enabled = false
}

resource "azurerm_cdn_frontdoor_route" "routing_rule_B" {
  for_each = {
    for frontend in var.new_frontends : frontend.name => frontend
    if lookup(frontend, "enable_ssl", true) && lookup(frontend, "redirect", null) == null
  }
  name                            = "${each.value.name}HttpsRedirect"
  cdn_frontdoor_endpoint_id       = azurerm_cdn_frontdoor_endpoint.endpoint.id
  cdn_frontdoor_origin_group_id   = azurerm_cdn_frontdoor_origin_group.defaultBackend.id
  cdn_frontdoor_origin_ids        = [azurerm_cdn_frontdoor_origin.defaultBackend_origin.id]
  cdn_frontdoor_custom_domain_ids = [azurerm_cdn_frontdoor_custom_domain.custom_domain[each.key].id]
  cdn_frontdoor_rule_set_ids      = [azurerm_cdn_frontdoor_rule_set.https_redirect.id]
  enabled                         = true

  supported_protocols    = ["Http"]
  patterns_to_match      = ["/*"]
  forwarding_protocol    = "MatchRequest"
  link_to_default_domain = false
  https_redirect_enabled = false
}

resource "azurerm_cdn_frontdoor_route" "routing_rule_C" {
  for_each = {
    for frontend in var.new_frontends : frontend.name => frontend
    if lookup(frontend, "www_redirect", false)
  }
  name                            = "${each.value.name}wwwRedirect"
  cdn_frontdoor_endpoint_id       = azurerm_cdn_frontdoor_endpoint.endpoint.id
  cdn_frontdoor_origin_group_id   = azurerm_cdn_frontdoor_origin_group.origin_group[each.key].id
  cdn_frontdoor_origin_ids        = [azurerm_cdn_frontdoor_origin.front_door_origin[each.key].id]
  cdn_frontdoor_custom_domain_ids = [azurerm_cdn_frontdoor_custom_domain.custom_domain[each.key].id]
  enabled                         = true

  supported_protocols    = ["Http", "Https"]
  patterns_to_match      = ["/*"]
  link_to_default_domain = true
  https_redirect_enabled = true
}

resource "azurerm_cdn_frontdoor_route" "routing_rule_D" {
  for_each = {
    for frontend in var.new_frontends : frontend.name => frontend
    if lookup(frontend, "redirect", null) != null
  }
  name                            = "${each.value.name}redirect"
  cdn_frontdoor_endpoint_id       = azurerm_cdn_frontdoor_endpoint.endpoint.id
  cdn_frontdoor_origin_group_id   = azurerm_cdn_frontdoor_origin_group.origin_group[each.key].id
  cdn_frontdoor_origin_ids        = [azurerm_cdn_frontdoor_origin.front_door_origin[each.key].id]
  cdn_frontdoor_custom_domain_ids = [azurerm_cdn_frontdoor_custom_domain.custom_domain[each.key].id]
  enabled                         = true

  supported_protocols    = ["Http", "Https"]
  patterns_to_match      = ["/*"]
  link_to_default_domain = true
  https_redirect_enabled = true
}

resource "azurerm_cdn_frontdoor_custom_domain" "custom_domain" {
  for_each = { for frontend in var.new_frontends : frontend.name => frontend
  if lookup(frontend, "ssl_mode", var.ssl_mode) != "AzureKeyVault" }
  name                     = each.value.name
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.front_door.id
  host_name                = each.value.custom_domain

  tls {
    certificate_type    = "ManagedCertificate"
    minimum_tls_version = "TLS12"
  }
}

resource "azurerm_cdn_frontdoor_custom_domain" "apex_custom_domain" {
  for_each = { for frontend in var.new_frontends : frontend.name => frontend
  if lookup(frontend, "ssl_mode", var.ssl_mode) == "AzureKeyVault" }
  name                     = each.value.name
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.front_door.id
  host_name                = each.value.custom_domain

  tls {
    certificate_type        = "CustomerCertificate"
    minimum_tls_version     = "TLS12"
    cdn_frontdoor_secret_id = azurerm_cdn_frontdoor_secret.certificate[each.key].id
  }
}

resource "azurerm_cdn_frontdoor_secret" "certificate" {
  for_each = { for frontend in var.new_frontends : frontend.name => frontend
  if lookup(frontend, "ssl_mode", var.ssl_mode) == "AzureKeyVault" }
  name                     = "${var.project}-${var.env}-managed-secret"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.front_door.id

  secret {
    customer_certificate {
      key_vault_certificate_id = data.azurerm_key_vault_certificate.certificate[each.key].id
    }
  }
}

resource "azurerm_cdn_frontdoor_custom_domain_association" "custom_association_A" {
  for_each = {
    for frontend in var.new_frontends : frontend.name => frontend
    if lookup(frontend, "redirect", null) == null
  }
  cdn_frontdoor_custom_domain_id = each.value.ssl_mode == "AzureKeyVault" ? azurerm_cdn_frontdoor_custom_domain.apex_custom_domain[each.key].id : azurerm_cdn_frontdoor_custom_domain.custom_domain[each.key].id
  cdn_frontdoor_route_ids        = [azurerm_cdn_frontdoor_route.routing_rule_A[each.key].id]
}

resource "azurerm_cdn_frontdoor_custom_domain_association" "custom_association_B" {
  for_each = {
    for frontend in var.new_frontends : frontend.name => frontend
    if lookup(frontend, "enable_ssl", true) && lookup(frontend, "redirect", null) == null
  }
  cdn_frontdoor_custom_domain_id = each.value.ssl_mode == "AzureKeyVault" ? azurerm_cdn_frontdoor_custom_domain.apex_custom_domain[each.key].id : azurerm_cdn_frontdoor_custom_domain.custom_domain[each.key].id
  cdn_frontdoor_route_ids        = [azurerm_cdn_frontdoor_route.routing_rule_B[each.key].id]
}

resource "azurerm_cdn_frontdoor_custom_domain_association" "custom_association_C" {
  for_each = {
    for frontend in var.new_frontends : frontend.name => frontend
    if lookup(frontend, "www_redirect", false)
  }
  cdn_frontdoor_custom_domain_id = each.value.ssl_mode == "AzureKeyVault" ? azurerm_cdn_frontdoor_custom_domain.apex_custom_domain[each.key].id : azurerm_cdn_frontdoor_custom_domain.custom_domain[each.key].id
  cdn_frontdoor_route_ids        = [azurerm_cdn_frontdoor_route.routing_rule_C[each.key].id]
}

resource "azurerm_cdn_frontdoor_custom_domain_association" "custom_association_D" {
  for_each = {
    for frontend in var.new_frontends : frontend.name => frontend
    if lookup(frontend, "redirect", null) != null
  }
  cdn_frontdoor_custom_domain_id = each.value.ssl_mode == "AzureKeyVault" ? azurerm_cdn_frontdoor_custom_domain.apex_custom_domain[each.key].id : azurerm_cdn_frontdoor_custom_domain.custom_domain[each.key].id
  cdn_frontdoor_route_ids        = [azurerm_cdn_frontdoor_route.routing_rule_D[each.key].id]
}
