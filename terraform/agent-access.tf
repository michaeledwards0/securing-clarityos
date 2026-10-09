# Excerpt from clarity-platform/terraform/main.tf (production, applied by CI).
# Not standalone: module outputs referenced here are defined elsewhere in the root module.

# --- Service-to-service auth between agents ---
# Until 2026-10-06 every internal hop was an unauthenticated public URL:
# n8n's kb-ask / kb-embed-document / summarize-inquiry webhooks (anyone who
# found the n8n hostname could pass another tenant's client_id to kb-ask and
# read its knowledge base, or burn Claude/Voyage spend -- OWASP LLM02/LLM10)
# and voice-relay's POST /booking/turn (can commit a real Cal.com booking).
# One shared secret per direction, so each caller only holds the secret for
# the hop it actually makes:
#   n8n-webhook-secret   dashboard + voice-relay  -> n8n webhooks
#   booking-turn-secret  n8n                      -> voice-relay /booking/turn
# n8n has no Key Vault access (see below), so the operator pastes both
# values into n8n credentials by hand -- see n8n/workflows/*.json notes.
resource "random_password" "internal_auth" {
  for_each = toset(["n8n-webhook-secret", "booking-turn-secret"])

  length  = 48
  special = false
}

resource "azurerm_key_vault_secret" "internal_auth" {
  for_each = random_password.internal_auth

  name         = each.key
  key_vault_id = module.keyvault.id
  value        = each.value.result

  depends_on = [time_sleep.kv_rbac_ready]
}

# --- Agent least privilege: per-secret Key Vault access ---
# Each workload identity ("agent") gets Key Vault Secrets User scoped to the
# individual secrets its code actually reads, not the whole vault. Before
# this (2026-10-05), all three identities held vault-wide Secrets User, so
# the voice receptionist could read stripe-secret-key and n8n could read
# everything despite never calling Key Vault at all (OWASP LLM06, excessive
# agency). Lists below come from grepping every getSecret/getOptionalSecret
# call in dashboard/ and voice-relay/src -- a new secret an app starts
# reading must be added here, which is the point: access is an explicit,
# reviewable allowlist in a PR diff.
#
# n8n's identity has no entry at all: no workflow reads Key Vault (its
# credentials live in n8n's own encrypted credential store), so its former
# vault-wide grant was pure excess and is removed outright.
#
# Rolled out in two applies so no app lost access mid-deploy: per-secret
# grants first (2026-10-05, alongside the old vault-wide ones), then the
# vault-wide dashboard_kv_reader/voice_kv_reader grants removed.
locals {
  agent_secret_access = {
    dashboard = {
      principal_id = module.app_service.identity_principal_id
      secrets = [
        "auth-secret",
        "calcom-api-key",
        "calendar-token-encryption-key",
        "entra-client-id",
        "entra-client-secret",
        "entra-issuer",
        "google-calendar-client-id",
        "google-calendar-client-secret",
        "google-client-id",
        "google-client-secret",
        "graph-calendar-client-id",
        "graph-calendar-client-secret",
        "n8n-webhook-secret",
        "postgres-connection-string",
        "postmark-from-email",
        "postmark-server-token",
        "stripe-secret-key",
        "stripe-webhook-secret",
        "twilio-account-sid",
        "twilio-auth-token",
      ]
    }
    voice = {
      principal_id = module.voice_relay.identity_principal_id
      secrets = [
        "anthropic-api-key",
        "booking-turn-secret",
        "calcom-api-key",
        "n8n-webhook-secret",
        "postgres-connection-string",
        "twilio-account-sid",
        "twilio-auth-token",
      ]
    }
  }

  agent_secret_grants = merge([
    for agent, access in local.agent_secret_access : {
      for secret in access.secrets : "${agent}/${secret}" => {
        principal_id = access.principal_id
        secret       = secret
      }
    }
  ]...)
}

resource "azurerm_role_assignment" "agent_secret_reader" {
  for_each = local.agent_secret_grants

  scope                = "${module.keyvault.id}/secrets/${each.value.secret}"
  role_definition_name = "Key Vault Secrets User"
  principal_id         = each.value.principal_id
  principal_type       = "ServicePrincipal"

  # A grant scoped to a secret that doesn't exist yet fails. Covers the
  # Terraform-created secrets above; hand-set ones (anthropic-api-key,
  # stripe-*, twilio-*) still have to exist before a fresh-environment apply.
  depends_on = [azurerm_key_vault_secret.internal_auth]
}
