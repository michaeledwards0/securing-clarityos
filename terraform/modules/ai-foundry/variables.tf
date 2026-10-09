variable "name" {
  description = "Foundry account name, also its globally-unique custom subdomain (<name>.openai.azure.com)."
  type        = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  description = "Region for the account. GlobalStandard quota is granted per subscription per region, so this must match the region the quota was requested in."
  type        = string
}

variable "voice_relay_principal_id" {
  description = "Principal ID of voice-relay's user-assigned managed identity, granted inference-only access."
  type        = string
}

variable "log_analytics_workspace_id" {
  type = string
}

variable "deploy_model" {
  description = "Create the model deployment. Leave false until GlobalStandard quota for model_name exists in location."
  type        = bool
  default     = false
}

variable "model_name" {
  type    = string
  default = "gpt-4.1-mini"
}

variable "model_version" {
  type    = string
  default = "2025-04-14"
}

variable "capacity_k_tpm" {
  description = "GlobalStandard capacity in thousands of tokens per minute."
  type        = number
  default     = 50
}

variable "tags" {
  type    = map(string)
  default = {}
}
