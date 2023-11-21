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
variable "frontends" {
  description = "Variable holds frontdoor configuration"
  type        = any
}

variable "subscription_id" {
  description = "Enter ID of subscription frontdoor is deployed to"
  type        = string
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
