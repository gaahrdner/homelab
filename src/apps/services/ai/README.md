# AI Services

This directory is the internal and experimental AI tier for the homelab.

## Scope

- `litellm`: internal model gateway
- `open-webui`: internal chat UI
- `langfuse`: internal tracing and evaluation

## Expectations

- These apps are important, but they are not in the same stability class as core platform services like networking, storage, secrets, or ArgoCD itself.
- Prefer changes here over changes to shared platform infrastructure when experimenting with agent tooling.
- Keep external exposure conservative. Default to internal DNS and Gateway API entrypoints unless there is a concrete reason to publish something more broadly.
