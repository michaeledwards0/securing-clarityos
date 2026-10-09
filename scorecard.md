# Scorecard — ClarityOS against OWASP LLM Top 10 (2025) and NIST AI RMF

Baseline: infrastructure review on 2026-10-03. "After" reflects what is applied in production now.

**Rating:** 🔴 exposed · 🟡 partial · 🟢 controlled

| OWASP LLM (2025) | Before | After | Control | NIST AI RMF function |
|---|---|---|---|---|
| **LLM01** Prompt injection (direct) | 🔴 caller speech reached models unfiltered | 🟢 voice: Prompt Shields on every utterance, Sentinel incident per caller, Defender for AI on Azure OpenAI traffic | `src/prompt-shield.ts`, `terraform/sentinel-detections.tf` | MEASURE, MANAGE |
| **LLM01** Prompt injection (indirect, via KB uploads) | 🔴 | 🔴 documents embedded unscreened | Next: Prompt Shields `documents` on upload | MAP |
| **LLM02** Sensitive information disclosure | 🔴 any tenant's KB readable through an unauthenticated webhook | 🟢 shared-secret auth per hop (403 verified); RLS enforced via `clarity_app` | `terraform/agent-access.tf`, `src/0008_app_role.sql` | MANAGE |
| **LLM03** Supply chain | 🔴 n8n `:latest`, unplanned schema migrations | 🟢 pinned `2.41.7`, upgrades by PR; model `NoAutoUpgrade`; Defender AI model scanner | container-apps, ai-foundry modules | GOVERN |
| **LLM04** Data and model poisoning | 🟡 | 🟡 KB uploads are tenant-scoped but unscreened | Next: indirect-injection screening | MEASURE |
| **LLM05** Improper output handling | 🔴 model output concatenated into JSON | 🟢 `JSON.stringify` | n8n `kb-ask` | MANAGE |
| **LLM06** Excessive agency | 🔴 every agent could read every secret; n8n bypassed RLS | 🟢 per-secret grants (dashboard 20, voice 7, n8n 0); n8n on its own login; keyless AI services; gateway is the only path to the model | `terraform/agent-access.tf` | GOVERN, MANAGE |
| **LLM07** System prompt leakage | 🟡 not assessed | 🟡 not yet reviewed or red-teamed | Next: red teaming | MEASURE |
| **LLM08** Vector and embedding weaknesses | 🔴 cross-tenant KB reads | 🟢 authenticated retrieval + tenant isolation in Postgres | as LLM02 | MANAGE |
| **LLM09** Misinformation | 🟡 | 🟡 answers grounded on tenant KB; no groundedness check | Next: groundedness detection | MEASURE |
| **LLM10** Unbounded consumption | 🔴 no limits | 🟢 per-agent token limits and token metrics at the AI gateway | `apim/ai-gateway-policy.xml` | MANAGE |

NIST AI RMF is mapped at the function level (Govern, Map, Measure, Manage).

## Also tracked
- **Unauthorized tool execution:** the model can commit real Cal.com bookings. Booking-turn endpoint now authenticated; abuse cases not yet red-teamed.
- **AI posture:** Defender CSPM AI-SPM inventories the AI workloads and their reachable data and identities.
