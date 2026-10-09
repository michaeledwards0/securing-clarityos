# Terraform

Copied from the private `clarity-platform` repo, which CI applies to production. Subscription, tenant and resource identifiers are not included.

| File | What it is |
|---|---|
| `agent-access.tf` | Service-to-service shared secrets, and per-secret Key Vault grants for each agent identity |
| `sentinel-detections.tf` | Sentinel onboarding, the prompt-attack analytics rule, and the two Azure Monitor log alerts |
| `defender.tf` | Defender CSPM and Defender for AI services plans |
| `modules/ai-foundry` | Foundry account (keyless), Azure OpenAI deployment, inference-only role, diagnostic logs |
| `modules/content-safety` | Content Safety account for Prompt Shields (keyless), caller role, diagnostic logs |
| `modules/api-management` | **[VERIFY: copy the API Management module here once merged]** |
