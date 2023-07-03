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