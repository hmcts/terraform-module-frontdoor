resource "azurerm_cdn_frontdoor_profile" "front_door" {
  name                = var.name == null ? "${var.project}-${var.env}" : var.name
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
  name                     = var.name == null ? "${var.project}-${var.env}" : var.name
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
  count                           = var.default_routing_rule ? 1 : 0
  name                            = "defaultRouting"
  cdn_frontdoor_endpoint_id       = azurerm_cdn_frontdoor_endpoint.endpoint.id
  cdn_frontdoor_origin_group_id   = azurerm_cdn_frontdoor_origin_group.defaultBackend.id
  cdn_frontdoor_origin_ids        = [azurerm_cdn_frontdoor_origin.defaultBackend_origin.id]
  cdn_frontdoor_custom_domain_ids = ["/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group}/providers/Microsoft.Cdn/profiles/${azurerm_cdn_frontdoor_profile.front_door.name}/customDomains/${azurerm_cdn_frontdoor_profile.front_door.name}-azurefd-net"]
  enabled                         = true

  supported_protocols    = ["Http", "Https"]
  patterns_to_match      = ["/*"]
  forwarding_protocol    = "MatchRequest"
  link_to_default_domain = false
  https_redirect_enabled = false
}
moved {
  from = azurerm_cdn_frontdoor_route.default_routing_rule
  to   = azurerm_cdn_frontdoor_route.default_routing_rule[0]
}

######## End defaults ########

resource "azurerm_cdn_frontdoor_origin_group" "origin_group" {
  for_each = { for frontend in var.frontends : frontend.name => frontend
  if lookup(frontend, "backend_domain", []) != [] ? true : false }
  name                     = lookup(each.value, "origin_group_name", each.value.name)
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
  for_each = { for frontend in var.frontends : frontend.name => frontend
  if lookup(frontend, "backend_domain", []) != [] ? true : false }
  name                          = lookup(each.value, "origin_group_name", each.value.name)
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.origin_group[each.key].id

  enabled                        = true
  host_name                      = each.value.backend_domain[0]
  http_port                      = lookup(each.value, "http_port", 80)
  https_port                     = 443
  origin_host_header             = lookup(each.value, "host_header", each.value.custom_domain)
  priority                       = 1
  weight                         = 50
  certificate_name_check_enabled = lookup(each.value, "certificate_name_check_enabled", true) ? true : false

  dynamic "azurerm_cdn_frontdoor_origin" {
    for_each = length(each.value.backend_domain) > 1 ? [1] : []

    content {
      name                          = lookup(each.value, "origin_group_name", each.value.name)
      cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.origin_group[each.key].id

      enabled                        = true
      host_name                      = each.value.backend_domain[1]
      http_port                      = lookup(each.value, "http_port", 80)
      https_port                     = 443
      origin_host_header             = lookup(each.value, "host_header", each.value.custom_domain)
      priority                       = 2
      weight                         = 50
      certificate_name_check_enabled = lookup(each.value, "certificate_name_check_enabled", true) ? true : false
    }
  }
}

resource "azurerm_cdn_frontdoor_route" "routing_rule_A" {
  for_each = {
    for frontend in var.frontends : frontend.name => frontend
    if lookup(frontend, "redirect", null) == null
  }
  name                            = lookup(each.value, "routing_rule_A_name", each.value.name)
  cdn_frontdoor_endpoint_id       = azurerm_cdn_frontdoor_endpoint.endpoint.id
  cdn_frontdoor_origin_group_id   = lookup(each.value, "backend_domain", []) == [] ? azurerm_cdn_frontdoor_origin_group.origin_group[each.value.backend].id : azurerm_cdn_frontdoor_origin_group.origin_group[each.key].id
  cdn_frontdoor_origin_ids        = lookup(each.value, "backend_domain", []) == [] ? [azurerm_cdn_frontdoor_origin.front_door_origin[each.value.backend].id] : [azurerm_cdn_frontdoor_origin.front_door_origin[each.key].id]
  cdn_frontdoor_custom_domain_ids = [azurerm_cdn_frontdoor_custom_domain.custom_domain[each.key].id]
  enabled                         = true

  dynamic "cache" {
    for_each = lookup(each.value, "cache_enabled", "true") == "true" ? [1] : []
    content {
      compression_enabled           = false
      query_string_caching_behavior = "UseQueryString"
    }
  }

  supported_protocols    = lookup(each.value, "enable_ssl", true) ? ["Https"] : ["Http"]
  patterns_to_match      = lookup(each.value, "url_patterns", ["/*"])
  forwarding_protocol    = lookup(each.value, "forwarding_protocol", "HttpOnly")
  link_to_default_domain = false
  https_redirect_enabled = false
  depends_on             = [azurerm_cdn_frontdoor_origin_group.origin_group, azurerm_cdn_frontdoor_origin.front_door_origin]
}

resource "azurerm_cdn_frontdoor_route" "routing_rule_B" {
  for_each = {
    for frontend in var.frontends : frontend.name => frontend
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
  depends_on             = [azurerm_cdn_frontdoor_origin_group.origin_group, azurerm_cdn_frontdoor_origin.front_door_origin]
}


################ ################  www_redirect ################ 

resource "azurerm_cdn_frontdoor_rule_set" "www_redirect_rule_set" {
  for_each = {
    for frontend in var.frontends : frontend.name => frontend
    if lookup(frontend, "www_redirect", false)
  }
  name                     = replace("${each.value.name}wwwredirectruleset", "-", "")
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.front_door.id
}

resource "azurerm_cdn_frontdoor_rule" "redirect_www" {
  for_each = {
    for frontend in var.frontends : frontend.name => frontend
    if lookup(frontend, "www_redirect", false)
  }
  name = replace("${each.value.name}wwwredirectrule", "-", "")

  cdn_frontdoor_rule_set_id = azurerm_cdn_frontdoor_rule_set.www_redirect_rule_set[each.key].id
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

resource "azurerm_cdn_frontdoor_route" "routing_rule_C" {
  for_each = {
    for frontend in var.frontends : frontend.name => frontend
    if lookup(frontend, "www_redirect", false)
  }
  name                            = "${each.value.name}wwwRedirect"
  cdn_frontdoor_endpoint_id       = azurerm_cdn_frontdoor_endpoint.endpoint.id
  cdn_frontdoor_origin_group_id   = azurerm_cdn_frontdoor_origin_group.origin_group[each.key].id
  cdn_frontdoor_origin_ids        = [azurerm_cdn_frontdoor_origin.front_door_origin[each.key].id]
  cdn_frontdoor_custom_domain_ids = [azurerm_cdn_frontdoor_custom_domain.custom_domain_www[each.key].id]
  cdn_frontdoor_rule_set_ids      = [azurerm_cdn_frontdoor_rule_set.www_redirect_rule_set[each.key].id]
  enabled                         = true

  supported_protocols    = ["Http", "Https"]
  patterns_to_match      = ["/*"]
  link_to_default_domain = false
  https_redirect_enabled = true
  depends_on             = [azurerm_cdn_frontdoor_origin_group.origin_group, azurerm_cdn_frontdoor_origin.front_door_origin, azurerm_cdn_frontdoor_custom_domain.custom_domain_www]
}

resource "azurerm_cdn_frontdoor_custom_domain" "custom_domain_www" {
  for_each = { for frontend in var.frontends : frontend.name => frontend
  if lookup(frontend, "www_redirect", false) }
  name                     = "www${each.value.name}"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.front_door.id
  host_name                = "www.${each.value.custom_domain}"

  tls {
    certificate_type        = lookup(each.value, "ssl_mode", "") == "AzureKeyVault" ? "CustomerCertificate" : "ManagedCertificate"
    minimum_tls_version     = "TLS12"
    cdn_frontdoor_secret_id = lookup(each.value, "ssl_mode", "") == "AzureKeyVault" ? azurerm_cdn_frontdoor_secret.certificate[each.key].id : null
  }
}

resource "azurerm_cdn_frontdoor_custom_domain_association" "custom_association_C" {
  for_each = {
    for frontend in var.frontends : frontend.name => frontend
    if lookup(frontend, "www_redirect", false)
  }
  cdn_frontdoor_custom_domain_id = azurerm_cdn_frontdoor_custom_domain.custom_domain_www[each.key].id
  cdn_frontdoor_route_ids        = [azurerm_cdn_frontdoor_route.routing_rule_C[each.key].id]
}
################ END of  www_redirect ################ 


################  redirect ################ 


resource "azurerm_cdn_frontdoor_origin_group" "origin_group_redirect" {
  for_each = { for frontend in var.frontends : frontend.name => frontend
    if lookup(frontend, "backend_domain", []) == [] && lookup(frontend, "redirect", null) != null
  }
  name                     = each.value.name
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.front_door.id
  session_affinity_enabled = false

  load_balancing {
    sample_size                        = 4
    successful_samples_required        = 2
    additional_latency_in_milliseconds = 0
  }

}

resource "azurerm_cdn_frontdoor_origin" "front_door_origin_redirect" {
  for_each = { for frontend in var.frontends : frontend.name => frontend
    if lookup(frontend, "backend_domain", []) == [] && lookup(frontend, "redirect", null) != null
  }
  name                          = each.value.name
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.origin_group_redirect[each.key].id

  enabled                        = true
  host_name                      = lookup(each.value, "host_header", each.value.custom_domain)
  http_port                      = lookup(each.value, "http_port", 80)
  https_port                     = 443
  priority                       = 1
  weight                         = 50
  certificate_name_check_enabled = true
}

resource "azurerm_cdn_frontdoor_rule_set" "redirect_hostname_rule_set" {
  for_each = {
    for frontend in var.frontends : frontend.name => frontend
    if lookup(frontend, "redirect", null) != null
  }

  name = replace("${each.value.name}redirectruleset", "-", "")

  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.front_door.id
}

resource "azurerm_cdn_frontdoor_rule" "redirect_hostname" {
  for_each = {
    for frontend in var.frontends : frontend.name => frontend
    if lookup(frontend, "redirect", null) != null
  }
  name = replace("${each.value.name}redirectrule", "-", "")

  cdn_frontdoor_rule_set_id = azurerm_cdn_frontdoor_rule_set.redirect_hostname_rule_set[each.key].id
  order                     = 1
  behavior_on_match         = "Continue"

  actions {
    url_redirect_action {
      redirect_type        = "Moved"
      redirect_protocol    = "Https"
      destination_hostname = each.value.redirect
    }
  }

  depends_on = [azurerm_cdn_frontdoor_origin_group.defaultBackend, azurerm_cdn_frontdoor_origin.defaultBackend_origin, azurerm_cdn_frontdoor_origin_group.origin_group_redirect, azurerm_cdn_frontdoor_origin.front_door_origin_redirect]
}

resource "azurerm_cdn_frontdoor_route" "routing_rule_D" {
  for_each = {
    for frontend in var.frontends : frontend.name => frontend
    if lookup(frontend, "redirect", null) != null
  }
  name                            = "${each.value.name}redirect"
  cdn_frontdoor_endpoint_id       = azurerm_cdn_frontdoor_endpoint.endpoint.id
  cdn_frontdoor_origin_group_id   = azurerm_cdn_frontdoor_origin_group.origin_group_redirect[each.key].id
  cdn_frontdoor_origin_ids        = [azurerm_cdn_frontdoor_origin.front_door_origin_redirect[each.key].id]
  cdn_frontdoor_custom_domain_ids = [azurerm_cdn_frontdoor_custom_domain.custom_domain[each.key].id]
  cdn_frontdoor_rule_set_ids      = [azurerm_cdn_frontdoor_rule_set.redirect_hostname_rule_set[each.key].id]
  enabled                         = true

  supported_protocols    = ["Http", "Https"]
  patterns_to_match      = ["/*"]
  link_to_default_domain = false

  depends_on = [azurerm_cdn_frontdoor_origin_group.defaultBackend, azurerm_cdn_frontdoor_origin.defaultBackend_origin, azurerm_cdn_frontdoor_origin_group.origin_group_redirect, azurerm_cdn_frontdoor_origin.front_door_origin_redirect]
}

################ end of redirect ################ 
resource "azurerm_cdn_frontdoor_custom_domain" "custom_domain" {
  for_each                 = { for frontend in var.frontends : frontend.name => frontend }
  name                     = each.value.name
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.front_door.id
  host_name                = each.value.custom_domain

  tls {
    certificate_type        = lookup(each.value, "ssl_mode", "") == "AzureKeyVault" ? "CustomerCertificate" : "ManagedCertificate"
    minimum_tls_version     = "TLS12"
    cdn_frontdoor_secret_id = lookup(each.value, "ssl_mode", "") == "AzureKeyVault" ? azurerm_cdn_frontdoor_secret.certificate[each.key].id : null
  }
}



resource "azurerm_cdn_frontdoor_secret" "certificate" {
  for_each = { for frontend in var.frontends : frontend.name => frontend
  if lookup(frontend, "ssl_mode", var.ssl_mode) == "AzureKeyVault" }
  name                     = "${replace("${each.value.name}", "-", "")}-managed-secret"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.front_door.id

  secret {
    customer_certificate {
      key_vault_certificate_id = data.azurerm_key_vault_certificate.certificate[each.key].versionless_id
    }
  }
}

resource "azurerm_cdn_frontdoor_custom_domain_association" "custom_association_A" {
  for_each = {
    for frontend in var.frontends : frontend.name => frontend
    if lookup(frontend, "redirect", null) == null
  }
  cdn_frontdoor_custom_domain_id = azurerm_cdn_frontdoor_custom_domain.custom_domain[each.key].id
  cdn_frontdoor_route_ids        = [azurerm_cdn_frontdoor_route.routing_rule_A[each.key].id]
}

resource "azurerm_cdn_frontdoor_custom_domain_association" "custom_association_B" {
  for_each = {
    for frontend in var.frontends : frontend.name => frontend
    if lookup(frontend, "enable_ssl", true) && lookup(frontend, "redirect", null) == null
  }
  cdn_frontdoor_custom_domain_id = azurerm_cdn_frontdoor_custom_domain.custom_domain[each.key].id
  cdn_frontdoor_route_ids        = [azurerm_cdn_frontdoor_route.routing_rule_B[each.key].id]
}



resource "azurerm_cdn_frontdoor_custom_domain_association" "custom_association_D" {
  for_each = {
    for frontend in var.frontends : frontend.name => frontend
    if lookup(frontend, "redirect", null) != null
  }
  cdn_frontdoor_custom_domain_id = azurerm_cdn_frontdoor_custom_domain.custom_domain[each.key].id
  cdn_frontdoor_route_ids        = [azurerm_cdn_frontdoor_route.routing_rule_D[each.key].id]
}

data "azurerm_dns_zone" "public_dns" {
  for_each = {
    for frontend in var.frontends : frontend.name => frontend
    if lookup(frontend, "hosted_externally", false) == false
  }
  provider            = azurerm.public_dns
  name                = each.value.dns_zone_name
  resource_group_name = "reformmgmtrg"
}

resource "azurerm_dns_txt_record" "public_dns_record" {
  for_each = {
    for frontend in var.frontends : frontend.name => frontend
    if lookup(frontend, "hosted_externally", false) == false
  }
  provider = azurerm.public_dns
  name = trimsuffix(
    join(".", ["_dnsauth",
      replace(each.value.custom_domain, each.value.dns_zone_name, "")
    ]),
  ".")
  zone_name           = data.azurerm_dns_zone.public_dns[each.key].name
  resource_group_name = data.azurerm_dns_zone.public_dns[each.key].resource_group_name
  ttl                 = 3600

  record {
    value = azurerm_cdn_frontdoor_custom_domain.custom_domain[each.key].validation_token == "" ? "validated" : azurerm_cdn_frontdoor_custom_domain.custom_domain[each.key].validation_token
  }
}
