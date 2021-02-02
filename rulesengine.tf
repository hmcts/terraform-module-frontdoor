resource "azurerm_template_deployment" "rules" {
  template_body       = data.template_file.rulesengine.rendered
  name                = "${var.project}-${var.env}-ruleEngine"
  resource_group_name = var.resource_group
  deployment_mode     = "Incremental"

  parameters = {
    frontdoors_name = azurerm_frontdoor.main.name
    ruleEngine_name = "${var.project}${var.env}"
    ruleName        = "httpsRedirect"
  }

  depends_on = [azurerm_frontdoor.main]
}