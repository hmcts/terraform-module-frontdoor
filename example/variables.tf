variable "env" {
  description = "Enter name of the enviornment to deploy frontdoor"
  type        = string
  default     = "sbox"
}
variable "project" {
  description = "Enter Name of the project"
  type        = string
  default     = "hmctslocaltest"
}
variable "location" {
  description = "Enter Azure location to deploy the resource"
  type        = string
  default     = "UK South"
}

variable "frontends" {
  description = "Variable holds frontdoor configuration"
  type        = any
}

variable "ssl_mode" {
  description = "Certificate source to encrypted HTTPS traffic with"
  type        = string
  default     = "AzureKeyVault"
}
variable "resource_group" {
  description = "Enter Resource Group Name"
  type        = string
  default     = "cft-platform-sbox-rg"
}
variable "certificate_key_vault_name" {
  description = "Name of the Keyvault that holds certificate"
  type        = string
  default     = "acmedcdcftappssbox"
}

variable "certificate_name_check" {
  description = "Enforce_backend_pools_certificate_name_check"
  type        = bool
  default     = true
}
variable "key_vault_resource_group" {
  description = "Keyvault resource group name"
  type        = string
  default     = "cft-platform-sbox-rg"
}

variable "caching_compression" {
  type = bool
}

variable "enable_cache" {
  type    = bool
  default = false
}