# Excerpt from clarity-platform/terraform/main.tf (production, applied by CI).
# Not standalone: module outputs referenced here are defined elsewhere in the root module.

# --- Microsoft Sentinel ---
# Onboarded on the existing clarity-logs workspace (31-day free trial for a
# workspace new to Sentinel; ~2.7 GB/month ingestion as of 2026-10-05).
# First custom detection: Prompt Shields hits on live calls, from the
# structured line voice-relay writes to stdout
# (voice-relay/src/prompt-shield.ts -> AppServiceConsoleLogs).
resource "azurerm_sentinel_log_analytics_workspace_onboarding" "this" {
  workspace_id = module.operations.log_analytics_workspace_id
}

locals {
  # extract(), not a bare parse_json(ResultDescription): App Service can
  # prefix console lines, and a prefix would make parse_json return null.
  voice_security_events_kql = <<-KQL
    AppServiceConsoleLogs
    | where _ResourceId has "clarity-voice"
    | where ResultDescription has "clarity-voice-relay"
    | extend d = parse_json(extract(@"(\{.*\})", 1, ResultDescription))
    | extend Event = tostring(d.event)
  KQL
}

resource "azurerm_sentinel_alert_rule_scheduled" "prompt_attack" {
  name                       = "clarity-voice-prompt-attack"
  log_analytics_workspace_id = azurerm_sentinel_log_analytics_workspace_onboarding.this.workspace_id
  display_name               = "Prompt injection attempt on ClarityOS AI receptionist"
  description                = "Azure AI Content Safety Prompt Shields flagged a live caller utterance as a prompt-injection / jailbreak attempt (OWASP LLM01). The receptionist deflected it without passing it to any model. Utterance is the prompt evidence."
  severity                   = "High"
  tactics                    = ["InitialAccess"]
  query_frequency            = "PT5M"
  query_period               = "PT5M"
  trigger_operator           = "GreaterThan"
  trigger_threshold          = 0

  query = <<-KQL
    ${local.voice_security_events_kql}
    | where Event == "prompt_attack_detected"
    | project TimeGenerated,
        ClientId = tostring(d.clientId),
        LeadId = tostring(d.leadId),
        Channel = tostring(d.channel),
        Turn = toint(d.turn),
        Utterance = tostring(d.utterance)
  KQL

  custom_details = {
    ClientId  = "ClientId"
    LeadId    = "LeadId"
    Channel   = "Channel"
    Utterance = "Utterance"
  }

  event_grouping {
    aggregation_method = "AlertPerResult"
  }

  incident {
    create_incident_enabled = true

    # One incident per caller (lead), not one per utterance -- a caller
    # trying five jailbreaks in one call is one investigation.
    grouping {
      enabled                 = true
      lookback_duration       = "PT1H"
      entity_matching_method  = "Selected"
      by_custom_details       = ["LeadId"]
      reopen_closed_incidents = false
    }
  }
}

# Sentinel incidents don't email on their own (that needs a Logic App
# playbook), so the same signal also goes to the ops action group as a
# plain log alert.
resource "azurerm_monitor_scheduled_query_rules_alert_v2" "prompt_attack" {
  name                 = "clarity-voice-prompt-attack"
  resource_group_name  = azurerm_resource_group.clarity["operations"].name
  location             = azurerm_resource_group.clarity["operations"].location
  scopes               = [module.operations.log_analytics_workspace_id]
  description          = "Prompt Shields blocked a prompt-injection attempt on a live call. See the matching Sentinel incident for the utterance."
  severity             = 1
  evaluation_frequency = "PT5M"
  window_duration      = "PT5M"
  tags                 = var.tags

  criteria {
    query                   = "${local.voice_security_events_kql}| where Event == 'prompt_attack_detected'"
    time_aggregation_method = "Count"
    operator                = "GreaterThan"
    threshold               = 0
  }

  action {
    action_groups = [module.monitoring.action_group_id]
  }
}

# The shield fails open (a Content Safety outage must not drop calls), so
# an outage has to be loud instead of silent.
resource "azurerm_monitor_scheduled_query_rules_alert_v2" "prompt_shield_unavailable" {
  name                 = "clarity-voice-prompt-shield-unavailable"
  resource_group_name  = azurerm_resource_group.clarity["operations"].name
  location             = azurerm_resource_group.clarity["operations"].location
  scopes               = [module.operations.log_analytics_workspace_id]
  description          = "Prompt Shields calls are failing, so caller input is reaching the models unscreened (fail-open)."
  severity             = 2
  evaluation_frequency = "PT5M"
  window_duration      = "PT15M"
  tags                 = var.tags

  criteria {
    query                   = "${local.voice_security_events_kql}| where Event == 'prompt_shield_unavailable'"
    time_aggregation_method = "Count"
    operator                = "GreaterThan"
    threshold               = 2
  }

  action {
    action_groups = [module.monitoring.action_group_id]
  }
}
