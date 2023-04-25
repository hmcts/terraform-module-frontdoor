# Add your DNS records here
#resource "azurerm_dns_cname_record" "test" {
#  provider = azurerm.mgmt
#
#  name                = "test"
#  record              = "${var.project}-${var.env}.azurefd.net"
#  resource_group_name = "reformmgmtrg"
#  ttl                 = 360
#  zone_name           = "sandbox.platform.hmcts.net"
#}
#
#resource "azurerm_dns_cname_record" "home" {
#  provider = azurerm.mgmt
#
#  name                = "home"
#  record              = "${var.project}-${var.env}.azurefd.net"
#  resource_group_name = "reformmgmtrg"
#  ttl                 = 360
#  zone_name           = "sandbox.platform.hmcts.net"
#}
