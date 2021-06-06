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

resource "null_resource" "rule_association" {
  for_each = {
    for frontend in var.frontends : frontend.name => frontend if lookup(host.value, "enable_ssl", true)
  }

  provisioner "local-exec" {
    command = <<EOF
      az login --service-principal --username $clientId --password $secret --tenant $tenantId
      az network front-door routing-rule update --front-door-name ${azurerm_frontdoor.main.name} --resource-group ${var.resource_group} --name ${each.value["name"]} --rules-engine ${var.project}${var.env}
    EOF
  }

  depends_on = [azurerm_template_deployment.rules]
}