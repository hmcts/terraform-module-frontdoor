variable "env" {
  description = "Enter name of the environment to deploy frontdoor"
  type        = string
}
variable "project" {
  description = "Name of the project"
  type        = string

}
variable "location" {
  description = "Azure location to deploy the resource"
  type        = string
  default     = "UK South"
}
variable "common_tags" {
  description = "Common tag to be applied"
  type        = map(string)
}

variable "send_access_logs_to_log_analytics" {
  description = "Send access logs to log analytics workspace, this can be quite expensive on busy FrontDoor instances so disable it and send to Storage account instead"
  default     = true
}

variable "ssl_mode" {
  description = "Certificate source to encrypt HTTPS traffic with. eg. AzureKeyVault, FrontDoor"
  type        = string
}
variable "resource_group" {
  description = "Enter Resource Group Name"
  type        = string
}
variable "certificate_key_vault_name" {
  description = "Name of the Keyvault that holds certificate"
  type        = string
  default     = null
}

variable "certificate_name_check" {
  description = "Enforce backend pools certificate name check"
  type        = bool
}
variable "key_vault_resource_group" {
  description = "Key Vault resource group name"
  type        = string
  default     = null
}

variable "add_access_policy" {
  default     = true
  type        = bool
  description = "Whether to add an access policy for frontdoor to the subscription key vault, disable if there's multiple front doors in one subscription"
}

variable "add_access_policy_role" {
  default     = true
  type        = bool
  description = "Whether to add a role assignment for frontdoor to the subscription key vault, disable if there's multiple front doors in one subscription"
}

variable "diagnostics_storage_account_id" {
  description = "ID of a storage account to send access logs to."
  default     = null
}
variable "log_analytics_workspace_id" {
  description = "Enter log analytics workspace id"
  type        = string
}

variable "front_door_sku_name" {
  description = "Specifies the SKU for this Front Door Profile"
  type        = string
  default     = "Premium_AzureFrontDoor"
}

variable "default_routing_rule" {
  type        = bool
  description = "Enable or disable this if the default routing rule needed"
  default     = true
}

variable "name" {
  type        = string
  default     = null
  description = "The default name will be project-env, you can override the product+component part by setting this"
}

variable "minimum_tls_version" {
  type        = string
  description = "The default TLS policy to apply to Front Door custom domain."
  default     = "TLS12"
}

variable "cipher_suite_policy" {
  description = <<-EOT
  TLS policy preset for Azure Front Door custom domains.
  Options:
    - null: Use Azure's default policy
    - "TLS12_2022": More compatible (includes DHE cipher suites)
    - "TLS12_2023": Higher security (may exclude older cipher suites)
  EOT

  type    = string
  default = null # Let Azure decide the default

  validation {
    condition     = var.cipher_suite_policy == null ? true : contains(["TLS12_2022", "TLS12_2023"], var.cipher_suite_policy)
    error_message = "Must be null, 'TLS12_2022', or 'TLS12_2023'"
  }
}

variable "rule_sets" {
  description = "Custom Front Door rule sets to create. Map keyed by an identifier; each value supports: name (string), frontends (list(string)) to associate with frontend routes, and rules (list of rule objects). Each rule supports name, order, optional behavior_on_match, conditions (object with lists per condition type), and actions (object with lists per action type)."
  type        = any
  default     = {}
}

variable "priority" {
  description = "Priority of the Origin host name for the custom domain"
  type        = number
  default     = 1
}

variable "weight" {
  description = "Weight of the Origin host name for the custom domain"
  type        = number
  default     = 50
}
