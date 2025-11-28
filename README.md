Terraform module to create Azure frontdoor resource.

## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| azurerm | n/a |

## Inputs

| Name | Description |      Type      |    Default    | Required |
|------|-------------|:--------------:|:-------------:|:--------:|
| certificate\_key\_vault\_name | Name of the Keyvault that holds certificate |    `string`    |      n/a      | yes |
| certificate\_name\_check | Enforce backend pools certificate name check |     `bool`     |      n/a      | yes |
| common\_tags | Common tag to be applied | `map(string)`  |      n/a      | yes |
| enable\_ssl | Enable SSL |     `bool`     |      n/a      | yes |
| env | Enter name of the environment to deploy frontdoor |    `string`    |      n/a      | yes |
| frontends | Variable holds frontdoor configuration |     `any`      |      n/a      | yes |
| key\_vault\_resource\_group | Key Vault resource group name |    `string`    |      n/a      | yes |
| location | Azure location to deploy the resource |    `string`    | `"UK South"`  | no |
| log\_analytics\_workspace\_id | Enter log analytics workspace id |    `string`    |      n/a      | yes |
| oms\_env | Name of the log analytics workspace |    `string`    |      n/a      | yes |
| project | Name of the project |    `string`    |      n/a      | yes |
| resource\_group | Enter Resource Group Name |    `string`    |      n/a      | yes |
| ssl\_mode | Certificate source to encrypt HTTPS traffic with. eg. AzureKeyVault, FrontDoor |    `string`    |      n/a      | yes |
| subscription\_id | Enter Subscription ID |    `string`    |      n/a      | yes |
| add\_access\_policy | Whether to add an access policy for frontdoor to the subscription key vault, disable if there's multiple front doors in one subscription |     `bool`     |     true      | no |
| add\_access\_policy_role | Whether to add a role assignment for frontdoor to the subscription key vault, disable if there's multiple front doors in one subscription |     `bool`     |     true      | no |
| new\_frontends | Variable holds new frontdoor configuration |     `map`      |      {}       | no |
| front\_door\_sku\_name | Specifies the SKU for this Front Door Profile |    `string`    |     null      | no |

## Outputs

No output.

