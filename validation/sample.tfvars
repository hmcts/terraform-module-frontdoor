project                    = "hmcts"
location                   = "uksouth"
env                        = "sbox"
subscription               = "sbox"
enable_ssl                 = true
ssl_mode                   = "AzureKeyVault"
certificate_key_vault_name = "cftapps-sbox"
certificate_name_check     = true
data_subscription          = "bf308a5c-0624-4334-8ff8-8dca9fd43783"
oms_env                    = "sandbox"
common_tags = {
  "managedBy"          = "Platform Engineering"
  "solutionOwner"      = "CFT"
  "activityName"       = "AKS"
  "dataClassification" = "Internal"
  "automation"         = ""
  "costCentre"         = "10245117" // until we get a better one, this is the generic cft contingency one
}
kv_resource_group = "core-infra-sbox-rg"
resource_group    = "lz-sbox-rg"
subscription_id   = "b72ab7b7-723f-4b18-b6f6-03b0f2c6a1bb"
frontends = [

  {
    name             = "toffee"
    custom_domain    = "toffee.sandbox.platform.hmcts.net"
    backend_domain   = ["firewall-sbox-int-palo-sbox.uksouth.cloudapp.azure.com"]
    certificate_name = "STAR-sandbox-platform-hmcts-net"
    disabled_rules   = {}
  }
]
