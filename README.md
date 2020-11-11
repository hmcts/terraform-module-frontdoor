# https://github.com/hmcts/terraform-module-frontdoor

Terraform module to create Azure frontdoor resource.

## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| azurerm | n/a |
| azurerm.data | n/a |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| certificate\_key\_vault\_name | Name of the Keyvault that holds certificate | `string` | n/a | yes |
| certificate\_name\_check | Enforce backend pools certificate name check | `bool` | n/a | yes |
| common\_tags | Common tag to be applied | `map(string)` | n/a | yes |
| enable\_ssl | Enable SSL | `bool` | n/a | yes |
| env | Enter name of the environment to deploy frontdoor | `string` | n/a | yes |
| frontends | Variable holds frontdoor configuration | `any` | n/a | yes |
| key\_vault\_resource\_group | Key Vault resource group name | `string` | n/a | yes |
| location | Enter Azure location to deploy the resource | `string` | `"UK South"` | no |
| oms\_env | Name of the log analytics workspace | `string` | n/a | yes |
| project | Enter Name of the project | `string` | `"hmcts"` | no |
| resource\_group | Enter Resource Group Name | `string` | n/a | yes |
| ssl\_mode | Certificate source to encrypt HTTPS traffic with. eg. AzureKeyVault, FrontDoor | `string` | n/a | yes |
| subscription | Name of the subscription to deploy frontdoor, e.g. stg | `string` | n/a | yes |
| subscription\_id | Enter Subscription ID | `string` | n/a | yes |

## Outputs

No output.

