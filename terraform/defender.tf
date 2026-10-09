# Excerpt from clarity-platform/terraform/main.tf (production, applied by CI).
# Not standalone: module outputs referenced here are defined elsewhere in the root module.

# --- Microsoft Defender for Cloud ---
# CI manages subscription-scoped Defender plans through the "Security Admin"
# grant codified in terraform/bootstrap (applied by a human, since CI can't
# grant itself a subscription-scoped role).
#
# Defender CSPM (enabled 2026-10-05, 30-day trial, then billed per resource):
# attack-path analysis, cloud security graph, and AI security posture
# management (AI-SPM) -- discovers AI workloads and their exposure (what
# data and identities each one can reach) on top of the free Foundational
# CSPM secure score already on. Extensions picked for what this estate
# actually has: sensitive-data discovery on the storage/Postgres data tier,
# Entra permissions management for the agent identities' effective access
# (dashboard/voice/n8n managed identities, CI), and API posture for the
# AI gateway planned in front of the model endpoints.
resource "azurerm_security_center_subscription_pricing" "cspm" {
  tier          = "Standard"
  resource_type = "CloudPosture"

  extension {
    name = "SensitiveDataDiscovery"
  }
  extension {
    name = "EntraPermissionsManagement"
  }
  extension {
    name = "ApiPosture"
  }
}

# Defender for AI services: threat protection on Azure-hosted model traffic
# (jailbreak/prompt injection, sensitive-data and credential leakage,
# wallet abuse). Enabled 2026-10-05 by the operator in the portal, then
# adopted here via the import block below so it's managed like CSPM.
# AIPromptEvidence attaches the offending prompt/response to each alert --
# what makes an alert actionable (and demo-able). AIModelScanner scans
# model artifacts for malware/unsafe serialization. Only Azure OpenAI /
# Azure AI Model Inference deployments are covered, which is why the model
# in docs/ai-security-track.md workstream 3 is an Azure OpenAI one.
import {
  to = azurerm_security_center_subscription_pricing.ai
  id = "/subscriptions/<subscription-id>/providers/Microsoft.Security/pricings/AI"
}

resource "azurerm_security_center_subscription_pricing" "ai" {
  tier          = "Standard"
  resource_type = "AI"

  extension {
    name = "AIPromptEvidence"
  }
  extension {
    name = "AIModelScanner"
  }
}
