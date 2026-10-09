terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

# Azure AI Content Safety, used for Prompt Shields on every live caller
# utterance (voice-relay/src/prompt-shield.ts) -- OWASP LLM01. S0, not F0:
# Prompt Shields is a Standard-tier feature.
#
# local_auth_enabled = false: no keys exist, voice-relay's managed identity
# is the only caller. custom_subdomain_name is required for Entra ID auth.
resource "azurerm_cognitive_account" "this" {
  name                  = var.name
  resource_group_name   = var.resource_group_name
  location              = var.location
  kind                  = "ContentSafety"
  sku_name              = "S0"
  custom_subdomain_name = var.name
  local_auth_enabled    = false
  tags                  = var.tags
}

# Cognitive Services User is the built-in role Content Safety's data plane
# (text:shieldPrompt) accepts for Entra ID callers -- scoped to this one
# account, not the resource group.
resource "azurerm_role_assignment" "caller" {
  for_each = var.caller_principal_ids

  scope                = azurerm_cognitive_account.this.id
  role_definition_name = "Cognitive Services User"
  principal_id         = each.value
  principal_type       = "ServicePrincipal"
}

resource "azurerm_monitor_diagnostic_setting" "this" {
  name                       = "diag-${var.name}"
  target_resource_id         = azurerm_cognitive_account.this.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category_group = "allLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}
