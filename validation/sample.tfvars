project                    = "ss"
location                   = "uksouth"
env                        = "sbox"
subscription               = "sbox"
enable_ssl                 = true
ssl_mode                   = "AzureKeyVault"
certificate_key_vault_name = "dtssharedservicessboxkv"
certificate_name_check     = true
data_subscription          = "a8140a9e-f1b0-481f-a4de-09e2ee23f7ab"
oms_env                    = "sandbox"
kv_resource_group          = "genesis-rg"
subscription_id            = "a8140a9e-f1b0-481f-a4de-09e2ee23f7ab"
frontends = [

  {
    name             = "toffee"
    custom_domain    = "toffee.sandbox.platform.hmcts.net"
    backend_domain   = ["firewall-sbox-int-palo-sbox.uksouth.cloudapp.azure.com"]
    certificate_name = "STAR-sandbox-platform-hmcts-net"
    disabled_rules   = {}
  }
]
common_tags    = {}
resource_group = ""