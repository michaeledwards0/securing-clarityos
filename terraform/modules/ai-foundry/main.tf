terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

# Azure AI Foundry resource (kind = AIServices) hosting an Azure OpenAI
# model for voice-relay's per-utterance classification calls (see
# voice-relay/src/claude.ts -> detectBookingIntent). Every caller's words
# pass through it, which puts live phone traffic in scope for Defender for
# AI services (jailbreak/prompt-injection, sensitive-data leakage, wallet
# abuse alerts, with prompt evidence).
#
# Azure OpenAI, not Claude-on-Foundry: Microsoft documents Defender for AI
# coverage for Azure OpenAI / Azure AI Model Inference models, not
# Anthropic deployments. The Claude Haiku version of this module (incl.
# the azapi workaround for azurerm's missing modelProviderData support,
# hashicorp/terraform-provider-azurerm#31140) is in git history at 7eb9e76.
#
# custom_subdomain_name is required for Entra ID token auth; with
# local_auth_enabled = false there are no API keys at all -- voice-relay's
# managed identity is the only way in.
resource "azurerm_cognitive_account" "foundry" {
  name                  = var.name
  resource_group_name   = var.resource_group_name
  location              = var.location
  kind                  = "AIServices"
  sku_name              = "S0"
  custom_subdomain_name = var.name
  local_auth_enabled    = false
  tags                  = var.tags

  # The Foundry portal flips this on when you browse Agents/Templates, and
  # a mismatch forces a destroy+recreate (hit 2026-10-01, see
  # docs/blocked-and-flagged.md) -- declared on from the start, with the
  # identity block azurerm requires alongside it.
  project_management_enabled = true

  identity {
    type = "SystemAssigned"
  }
}

# Off until the model quota request filed 2026-10-05 is approved: a
# deployment with 0 quota fails the whole apply with InsufficientQuota.
resource "azurerm_cognitive_deployment" "model" {
  count = var.deploy_model ? 1 : 0

  name                 = var.model_name
  cognitive_account_id = azurerm_cognitive_account.foundry.id

  model {
    format  = "OpenAI"
    name    = var.model_name
    version = var.model_version
  }

  sku {
    name     = "GlobalStandard"
    capacity = var.capacity_k_tpm
  }

  # Microsoft's default content filter (prompt/completion harm categories
  # plus jailbreak "Prompt Shields") applies at the model layer, in
  # addition to Defender's detections.
  rai_policy_name        = "Microsoft.DefaultV2"
  version_upgrade_option = "NoAutoUpgrade"
}

# Narrowest built-in role that can call deployed models: inference only,
# no access to keys, deployments or account settings.
resource "azurerm_role_assignment" "voice_openai_user" {
  scope                = azurerm_cognitive_account.foundry.id
  role_definition_name = "Cognitive Services OpenAI User"
  principal_id         = var.voice_relay_principal_id
  principal_type       = "ServicePrincipal"
}

# Request/response and audit logs to the shared workspace -- the raw
# material for the Sentinel analytics rules in workstream 5.
resource "azurerm_monitor_diagnostic_setting" "foundry" {
  name                       = "diag-clarity-foundry"
  target_resource_id         = azurerm_cognitive_account.foundry.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "Audit"
  }
  enabled_log {
    category = "RequestResponse"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}
