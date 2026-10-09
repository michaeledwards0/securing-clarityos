# Screenshot checklist

Save each file with the exact name below. Blur client IDs, lead IDs, phone numbers, subscription and tenant IDs before committing.

| File | Where to capture it |
|---|---|
| `phase-1/01-kv-vault-wide-grants-before.png` | Key Vault → Access control (IAM) → Role assignments, from before the change (Activity log, or a saved screenshot) |
| `phase-1/02-kb-ask-unauthenticated-before.png` | The original request/response showing a cross-tenant read (if you kept one); otherwise skip and describe it |
| `phase-1/03-n8n-unplanned-migrations.png` | Postgres `n8n` database → `migrations` table, ordered by timestamp |
| `phase-2/01-kv-per-secret-grants.png` | Key Vault → Secrets → `stripe-secret-key` → Access control (IAM): only the dashboard identity |
| `phase-2/02-kb-ask-403.png` | Terminal: `curl -i <n8n-host>/webhook/kb-ask?client_id=...` returning 403 |
| `phase-2/03-foundry-local-auth-disabled.png` | Foundry resource → Keys and Endpoint (keys disabled) or JSON view showing `disableLocalAuth: true` |
| `phase-2/04-model-deployment.png` | Foundry portal → Deployments → the Azure OpenAI deployment |
| `phase-2/05-apim-policy.png` | API Management → APIs → Azure OpenAI → All operations → Policy code view |
| `phase-2/06-apim-token-limit-429.png` | Terminal or APIM Test tab showing a 429 after exceeding the limit |
| `phase-2/07-token-metrics-by-agent.png` | Application Insights → Metrics → namespace `clarity-ai-gateway`, split by Agent |
| `phase-3/01-sentinel-incident.png` | Sentinel → Incidents → a prompt-injection incident → custom details |
| `phase-3/02-sentinel-rule.png` | Sentinel → Analytics → the rule's Set rule logic tab |
| `phase-3/03-defender-attack-path.png` | Defender for Cloud → Attack path analysis |
| `phase-3/04-ai-spm-inventory.png` | Defender for Cloud → Inventory, filtered to AI workloads (or Cloud security explorer, AI query) |
| `phase-3/05-defender-for-ai-alert.png` | Defender for Cloud → Security alerts → an AI alert with prompt evidence |
