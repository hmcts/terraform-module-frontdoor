resource "azurerm_cdn_frontdoor_profile" "my_front_door" {
  name                = "test-${var.project}-${var.env}"
  resource_group_name = var.resource_group
  sku_name            = var.front_door_sku_name
}

resource "azurerm_cdn_frontdoor_endpoint" "my_endpoint" {
  name                     = "test-${var.project}-${var.env}"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.my_front_door.id
}

resource "azurerm_cdn_frontdoor_origin_group" "my_origin_group" {
  name                     = "toffee3"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.my_front_door.id
  session_affinity_enabled = false

  load_balancing {
   sample_size                 = 4
   successful_samples_required = 2
   additional_latency_milliseconds = 0
  }

  health_probe {
    path                = "/health/liveness"
    request_type        = "HEAD"
    protocol            = "Http"
    interval_in_seconds = 120
  }
}
#     dynamic "origin_group_load_balancing" {
#         iterator = host
#         for_each = [
#       for frontend in var.frontends : frontend if lookup(frontend, "backend_domain", []) != [] ? true : false
#         ]
#         load_balancing {
#             sample_size                 = 4
#             successful_samples_required = 2
#             additional_latency_milliseconds = 0
#         }
#     }
    # dynamic "origin_group_health_probe" {
    #     iterator = host
    #     for_each = [
    #   for frontend in var.frontends : frontend if lookup(frontend, "backend_domain", []) != [] ? true : false
    #     ]
    #     health_probe {
    #         path                = lookup(host.value, "health_path", "/health/liveness")
    #         request_type        = "HEAD"
    #         protocol            = lookup(host.value, "health_protocol", "Http")
    #         interval_in_seconds = 120
    #     }
    # }


resource "azurerm_cdn_frontdoor_origin" "my_app_service_origin" {
  name                          = "test-${var.project}-${var.env}"
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.my_origin_group.id

  enabled                        = true
  host_name                      = "firewall-sbox-int-palo-sdssbox.uksouth.cloudapp.azure.com"
  http_port                      = 80
  https_port                     = 443
  origin_host_header             = "toffee3.sandbox.platform.hmcts.net"
  priority                       = 1
  weight                         = 50
  certificate_name_check_enabled = true
}

resource "azurerm_cdn_frontdoor_route" "my_route" {
  name                          = "toffee3"
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.my_endpoint.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.my_origin_group.id
  cdn_frontdoor_origin_ids      = [azurerm_cdn_frontdoor_origin.my_app_service_origin.id]
  enabled                = true

  supported_protocols    = ["Https"]
  patterns_to_match      = ["/*"]
  forwarding_protocol    = "HttpOnly"
  link_to_default_domain = true
  https_redirect_enabled = true
}

resource "azurerm_cdn_frontdoor_firewall_policy" "custom" {
  name                              = "toffee3sboxPremium"
  resource_group_name               = var.resource_group
  sku_name                          = azurerm_cdn_frontdoor_profile.my_front_door.sku_name
  enabled                           = true
  mode                              = "Prevention"

  managed_rule {
    type    = "DefaultRuleSet"
    version = "1.0"
  }

resource "azurerm_cdn_frontdoor_security_policy" "test_security_policy" {
  name                     = "Example-Security-Policy"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.my_front_door.id

  security_policies {
    firewall {
      cdn_frontdoor_firewall_policy_id = azurerm_cdn_frontdoor_firewall_policy.custom.id

      association {
        domain {
          cdn_frontdoor_domain_id = azurerm_cdn_frontdoor_endpoint.my_endpoint.id
        }
        patterns_to_match = ["/*"]
      }
    }
  }
}