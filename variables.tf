variable "env" {
  description = "Enter name of the environment to deploy frontdoor"
  type        = string
}
variable "subscription" {
  description = "Name of the subscription to deploy frontdoor, e.g. stg"
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
variable "frontends" {
  description = "Variable holds frontdoor configuration"
  type        = any
}
variable "subscription_id" {
  description = "Enter Subscription ID"
  type        = string
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
}
variable "oms_env" {
  description = "Name of the log analytics workspace"
  type        = string
}
variable "certificate_name_check" {
  description = "Enforce backend pools certificate name check"
  type        = bool
}
variable "key_vault_resource_group" {
  description = "Key Vault resource group name"
  type        = string
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

variable "log_analytics_workspace_id" {
  description = "Enter log analytics workspace id"
  type        = string
}
