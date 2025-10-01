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

Below is an example that reproduces the UI configuration shown in the screenshot using the new `rule_sets` input. It creates a rule set named `idamwebpubliccaching` with three rules and associates it with specific frontends.

Notes
- Use the `frontends` list inside each rule set to attach it to frontend routes created by this module (keys must match your `frontends[*].name`).
- Set `behavior_on_match = "Stop"` on a rule when you want to stop evaluating remaining rules after it matches.
- If you need to override the origin group for a rule, set `cdn_frontdoor_origin_group_id` to the ID of the desired origin group. If you keep it `null`, the route's default origin group is used.

Example usage

module "frontdoor" {
  source = "../" # or the module source
  # ... existing required inputs ...

  rule_sets = {
    idamwebpubliccaching = {
      name      = "idamwebpubliccaching"
      frontends = ["your-frontend-key"]

      rules = [
        // 1) IF Query string contains client_id=test-public-service (lowercase) THEN route override: HTTP only, caching disabled
        {
          name              = "testhmctaccessmigration"
          order             = 1
          behavior_on_match = "Continue"
          conditions = {
            query_string_conditions = [{
              operator     = "Contains"
              match_values = ["client_id=test-public-service"]
              transforms   = ["Lowercase"]
            }]
          }
          actions = {
            route_configuration_override_actions = [{
              cdn_frontdoor_origin_group_id = null         # keep route's default origin group
              forwarding_protocol           = "HttpOnly"  # HTTP only
              cache_behavior                = "BypassCache" # caching disabled
            }]
          }
        },

        // 2) IF Request cookies cookie_name=idam.request operator Any THEN route override: HTTP only, caching disabled; Stop evaluating remaining rules
        {
          name              = "testhmctaccessmigration2"
          order             = 2
          behavior_on_match = "Stop"  # Stop evaluating remaining rules (like the checkbox in UI)
          conditions = {
            request_cookies_conditions = [{
              selector = "idam.request"  # cookie name
              operator = "Any"
            }]
          }
          actions = {
            route_configuration_override_actions = [{
              cdn_frontdoor_origin_group_id = null
              forwarding_protocol           = "HttpOnly"
              cache_behavior                = "BypassCache"
            }]
          }
        },

        // 3) IF Request file extension equals jpg png css ico js (lowercase) THEN caching enabled, use query string, honor origin
        {
          name  = "idamwebpubliccachingrule"
          order = 3
          conditions = {
            url_file_extension_conditions = [{
              operator     = "Equal"
              match_values = ["jpg", "png", "css", "ico", "js"]
              transforms   = ["Lowercase"]
            }]
          }
          actions = {
            route_configuration_override_actions = [{
              cache_behavior                = "HonorOrigin"
              query_string_caching_behavior = "UseQueryString"
              compression_enabled           = false
            }]
          }
        }
      ]
    }
  }
}

## Example: Overwrite origin group on cookie match

The following example shows how to send traffic to a different origin group when a cookie is present. You can now use a convenience field `cdn_frontdoor_origin_group_key` to reference an origin group created by this module by its frontend key, or the literal key `"defaultBackend"` to point to the module’s default origin group. You can still use `cdn_frontdoor_origin_group_id` if you want to pass an explicit resource ID.

Notes
- The value of `cdn_frontdoor_origin_group_key` must match one of your `frontends[*].name` entries (for module-managed origin groups), or `defaultBackend`.
- If both `cdn_frontdoor_origin_group_id` and `cdn_frontdoor_origin_group_key` are provided, the explicit ID wins.

Example usage snippet (inside your module call):

rule_sets = {
  cookie_ab_switch = {
    name      = "cookie_ab_switch"
    frontends = ["my-frontend"]
    rules = [
      {
        name              = "switch-to-beta-on-cookie"
        order             = 1
        behavior_on_match = "Stop"
        conditions = {
          request_cookies_conditions = [{
            selector = "ab"
            operator = "Equal"
            match_values = ["beta"]
          }]
        }
        actions = {
          route_configuration_override_actions = [{
            cdn_frontdoor_origin_group_key = "my-frontend-beta" # send to the origin group keyed by this frontend name
            forwarding_protocol           = "HttpOnly"
            cache_behavior                = "BypassCache"
          }]
        }
      }
    ]
  }
}

## Outputs

No output.

