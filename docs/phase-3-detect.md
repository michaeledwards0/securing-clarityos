# Phase 3 — Detect

## Prompt Shields on every caller utterance (F1)

Code: [`src/prompt-shield.ts`](../src/prompt-shield.ts) · Terraform: [`modules/content-safety`](../terraform/modules/content-safety/main.tf)

voice-relay sends every caller utterance to **Azure AI Content Safety Prompt Shields** before it reaches any model: booking-intent classification, slot matching or the knowledge-base pipeline.

- **Attack detected:** the receptionist deflects without passing the utterance to a model, and writes one JSON line to stdout: `{"source":"clarity-voice-relay","event":"prompt_attack_detected", ...}`.
- **Auth:** voice-relay's managed identity. The Content Safety account has key auth disabled.
- **Timeout:** 1.5 seconds. On a live call, a slow check is dead air.
- **Fails open, loudly.** If Content Safety is down, calls keep working and a `prompt_shield_unavailable` event is logged instead. Dropping every call during an outage would be worse for customers than briefly unscreened input, but the gap must never be silent.

## Sentinel: one incident per caller

Terraform: [`terraform/sentinel-detections.tf`](../terraform/sentinel-detections.tf) · KQL: [`kql/`](../kql)

App Service console logs flow to Log Analytics, where Sentinel is onboarded.

| Rule | Type | Fires when | Severity |
|---|---|---|---|
| Prompt injection attempt on ClarityOS AI receptionist | Sentinel scheduled analytics rule → **incident** | Any `prompt_attack_detected` in 5 min | High |
| Same signal | Azure Monitor log alert → ops email | Same | 1 |
| Prompt Shield unavailable | Azure Monitor log alert → ops email | >2 `prompt_shield_unavailable` in 15 min | 2 |

Design choices in the Sentinel rule:
- **Incident grouping by caller (`LeadId`), 1-hour lookback.** A caller who tries five jailbreaks in one call is one investigation, not five.
- **Custom details** carry the client, lead, channel and the utterance itself, so the analyst sees the prompt evidence in the incident.
- **Mapped to MITRE ATT&CK Initial Access.**
- The parser uses `extract()` before `parse_json()` because App Service can prefix console lines, which would make a bare `parse_json` return null and the rule silently never fire.
- The email alert exists because Sentinel incidents don't notify on their own without a Logic App playbook.

## Defender for Cloud

Terraform: [`terraform/defender.tf`](../terraform/defender.tf)

| Plan | Extensions | What it gives me |
|---|---|---|
| **Defender CSPM** | Sensitive data discovery, Entra permissions management, API posture | Attack-path analysis, the cloud security graph, and **AI security posture management**: which AI workloads exist and what data and identities each one can reach |
| **Defender for AI services** | AI prompt evidence, AI model scanner | Threat alerts on Azure OpenAI traffic (jailbreak, sensitive-data leakage, wallet abuse) with the offending prompt attached |

Defender for AI is the reason the booking classifier runs on Azure OpenAI rather than Claude: it can only inspect Azure-hosted model traffic.

## Results

See the [scorecard](../scorecard.md) for before/after against OWASP LLM Top 10 (2025) and NIST AI RMF.

## Evidence

- `screenshots/phase-3/01-sentinel-incident.png` — incident with the utterance in custom details (blur client/lead IDs)
- `screenshots/phase-3/02-sentinel-rule.png`
- `screenshots/phase-3/03-defender-attack-path.png`
- `screenshots/phase-3/04-ai-spm-inventory.png`
- `screenshots/phase-3/05-defender-for-ai-alert.png` — an alert with prompt evidence, from a test jailbreak against the Azure OpenAI deployment
