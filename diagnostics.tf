resource "azurerm_monitor_diagnostic_setting" "frontdoor_diagnostics" {
  name                       = "fd-log-analytics"
  target_resource_id         = azurerm_cdn_frontdoor_profile.front_door.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "FrontdoorWebApplicationFirewallLog"
  }

  metric {
    category = "AllMetrics"
  }
}

resource "azurerm_monitor_diagnostic_setting" "diagnostics_access_logs_la" {
  count = var.send_access_logs_to_log_analytics ? 1 : 0

  name                       = "fd-log-analytics-logs"
  target_resource_id         = azurerm_cdn_frontdoor_profile.front_door.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "FrontdoorAccessLog"
  }
}

resource "azurerm_monitor_diagnostic_setting" "diagnostics_access_logs_sa" {
  count = var.diagnostics_storage_account_id != null ? 1 : 0

  name               = "fd-log-analytics-logs-sa"
  target_resource_id = azurerm_cdn_frontdoor_profile.front_door.id
  storage_account_id = var.diagnostics_storage_account_id

  enabled_log {
    category = "FrontdoorAccessLog"
  }
}
