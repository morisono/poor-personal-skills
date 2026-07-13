---
name: cloudflare-deepseek-cost-guard
description: Audit Cloudflare x DeepSeek integrations for cost-control gaps, abuse surface, and runaway token spend. Use when reviewing a website AI feature, backend relay, or gateway policy.
---

# Cloudflare x DeepSeek Cost Guard

Use this skill to verify that an AI feature cannot silently accumulate spend through avoidable model calls, oversized prompts, uncapped outputs, or missing policy controls.

## What to inspect

Check the integration as an execution path, not as a feature description.

Inspect for these control classes:
- ingress control: only the intended backend can reach the model path
- request shaping: prompt size, context window, output cap, and tool-call limits
- caching: deterministic or near-deterministic responses are reused
- routing: cheap path first, expensive path only on escalation
- fallback: bounded retries, bounded fallback depth, and failure containment
- spend fencing: explicit budget ceilings, tenant ceilings, and model ceilings
- async offload: non-interactive work is queued instead of executed inline
- observability: cost attribution by endpoint, tenant, model, and feature
- data hygiene: PII/DLP gates before model invocation
- abuse resistance: authentication, authorization, and replay resistance

## Review sequence

Start at the call site. Confirm the model is not reachable directly from the browser or any untrusted client. Then verify the backend or Worker applies policy before forwarding a request.

After that, inspect the cost surface in this order:
- cacheability
- prompt trimming
- output bounding
- model selection
- retries and fallback
- spend caps
- queueing and deferred execution
- logging and attribution

## Pass criteria

Treat the integration as acceptable only when all of the following are true:
- the model call is proxied through a controlled boundary
- a spend ceiling exists outside the application logic
- cacheable requests are cached at the gateway or edge
- retries cannot fan out into repeated expensive calls
- the default route uses the least expensive viable model
- expensive models require explicit escalation
- background work does not block the user path
- request metadata is sufficient to identify the cost driver
- the system can reject malformed, oversized, or sensitive inputs before inference

## Failure patterns

Flag these immediately:
- direct client-side calls to DeepSeek or any upstream LLM endpoint
- uncapped retries with no backoff or attempt limit
- repeated summarization of unchanged conversations
- multi-turn prompts that resend full history without pruning
- “temporary” debug logging that stores full prompts or responses
- fallback chains that escalate through several expensive models
- queue-less batch jobs that do model work inline
- shared API keys across tenants with no spend attribution
- cache keys that ignore prompt versioning or policy versioning
- no explicit rule for maximum completion length

## Output shape

Return a short verdict, then the defects grouped by severity:
- critical: direct spend leakage or missing containment
- major: cost amplification or weak attribution
- minor: inefficiency without immediate runaway risk

For each defect, include:
- location
- control that is missing
- likely spend impact
- minimal remediation

## Use the helper scripts

Run the helper that matches the platform or environment:
- POSIX shell: `scripts/audit.sh`
- PowerShell Core: `scripts/audit.ps1`
- Python: `scripts/audit.py`

Use the Python helper for multi-file scans, structured reports, or JSON output.
