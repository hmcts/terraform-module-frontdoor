
resource "azurerm_monitor_diagnostic_setting" "frontdoor_diagnostics" {
  name                       = "fd-log-analytics"
  target_resource_id         = azurerm_cdn_frontdoor_profile.my_front_door.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "FrontdoorAccessLog"

    retention_policy {
      enabled = true
      days    = 7
    }
  }

  enabled_log {
    category = "FrontdoorWebApplicationFirewallLog"
    retention_policy {
      enabled = true
      days    = 30
    }
  }

  metric {
    category = "AllMetrics"

    retention_policy {
      enabled = true
      days    = 30
    }
  }
}
