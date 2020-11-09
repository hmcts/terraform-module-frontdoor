variable "env" {
    description = "Enter name of the enviornment to deploy frontdoor"
    type = string 
}
variable "subscription" {
   description = "Enter name of the subsription to deploy frontdoor"
    type = string  
}
variable "project" {
    description = "Enter Name of the project"
    type = string
    default = "hmcts"
}
variable "location" {
    description = "Enter Azure location to deploy the resource"
    type = string 
    default = "UK South"
}
variable "common_tags" {
    description = "Common tag to be applied"
    type = map(string)
}
variable "frontends" {
    description = "Variable holds frontdoor configuration"
    type =  any 
}
variable "subscription_id" {
    description = "Enter ID of control Subscription"
    type = string  
}
variable "enable_ssl" {
    description = "Enable SSL"
    type =  bool  
}
variable "ssl_mode" {
    description = "Certificate source to encrypted HTTPS traffic with"
    type = string  
}
variable "resource_group" {
    description = "Enter Resource Group Name"
    type = string  
}
variable "certificate_key_vault_name" {
    description = "Name of the Keyvault that holds certificate"
    type = string  
}
variable "oms_env" {
    description = "Name of the Monitoring enviornment"
    type = string  
}
variable "certificate_name_check" {
    description = "Enforce_backend_pools_certificate_name_check"
    type = bool  
}
variable "kv_resource_group" {
    description = "Keyvault resource group name"
    type = string
}