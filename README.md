Terraform module to create Azure frontdoor resource.

## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| azurerm | n/a |

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
| location | Azure location to deploy the resource | `string` | `"UK South"` | no |
| log\_analytics\_workspace\_id | Enter log analytics workspace id | `string` | n/a | yes |
| oms\_env | Name of the log analytics workspace | `string` | n/a | yes |
| project | Name of the project | `string` | n/a | yes |
| resource\_group | Enter Resource Group Name | `string` | n/a | yes |
| ssl\_mode | Certificate source to encrypt HTTPS traffic with. eg. AzureKeyVault, FrontDoor | `string` | n/a | yes |
| subscription\_id | Enter Subscription ID | `string` | n/a | yes |
| add\_access\_policy | Whether to add an access policy for frontdoor to the subscription key vault, disable if there's multiple front doors in one subscription | `bool` | true | no |
| add\_access\_policy_role | Whether to add a role assignment for frontdoor to the subscription key vault, disable if there's multiple front doors in one subscription | `bool` | true | no |
| new\_frontends | Variable holds new frontdoor configuration | `map` | {} | no |
| front\_door\_sku\_name | Specifies the SKU for this Front Door Profile | `string` | null | no |
| rule_sets | Custom Front Door rule sets to create and optionally associate with routes. Map keyed by identifier. Each value: name, frontends, and rules (with conditions and actions). | `map(any)` | `{}` | no |

## Example: Custom rule set configuration

Below are examples for custom rules that dynamically change the backend origin group and caching behavior based on query string parameters or cookies.

Notes
- Use the `frontends` list inside each rule set to attach it to frontend routes created by this module (keys must match your `frontends[*].name`).
- Set `behavior_on_match = "Stop"` on a rule when you want to stop evaluating remaining rules after it matches.
- If you need to override the origin group for a rule, set `cdn_frontdoor_origin_group_id` to the ID of the desired origin group. If you keep it `null`, the route's default origin group is used.

Example usage
```
module "frontdoor" {
  source = "../" # or the module source
  # ... existing required inputs ...

  rule_sets = {
    hmcts-access-overrides = {
    name = "hmcts-access-overrides"
    frontends = ["idam-web-public"]

    rules = [
      # ──────────────────────────────────────────────
      # Rule 1: Query string contains client_id=...
      # ──────────────────────────────────────────────
      {
        name              = "Test"
        order             = 1
        
        conditions = {
          query_string_conditions = [
            {
              operator         = "Contains"
              negate_condition = false
              match_values = [
                "client_id=test-public-service"
              ]
              transforms = ["Lowercase"]  
            }
          ]
        }

        actions = {
          route_configuration_override_actions = [
            {
              # This key must exist in local.origin_group_ids
              cdn_frontdoor_origin_group_key = "hmcts-access"
              forwarding_protocol            = "HttpOnly"   
              cache_behavior                 = "BypassCache" # “Caching: Disabled”
            }
          ]
        }
      },

      # ──────────────────────────────────────────────
      # Rule 2: Cookie idam.request exists (Any)
      # ──────────────────────────────────────────────
      {
        name  = "UseHmctsAccedsIfCookieExists"
        order = 2
        # behavior_on_match = "Stop"  # if you want to stop after this rule

        conditions = {
          cookies_conditions = [
            {
              cookie_name      = "idam.request"
              operator         = "Any"
              negate_condition = false
              # no match_values required for "Any"
            }
          ]
        }

        actions = {
          route_configuration_override_actions = [
            {
              cdn_frontdoor_origin_group_key = "hmcts-access"
              forwarding_protocol            = "HttpOnly"
              cache_behavior                 = "BypassCache"
            }
          ]
        }
      }
    ]
  }
}
```
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

