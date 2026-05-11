# AI Services

This directory is the internal and experimental AI tier for the homelab.

## Scope

- `litellm`: internal model gateway
- `open-webui`: internal chat UI
- `langfuse`: internal tracing and evaluation
- `gascity`: staged only for now; image publishing and cluster-side manifests are in Git, but there is no live Argo application yet

## Expectations

- These apps are important, but they are not in the same stability class as core platform services like networking, storage, secrets, or ArgoCD itself.
- Prefer changes here over changes to shared platform infrastructure when experimenting with agent tooling.
- Keep external exposure conservative. Default to internal DNS and Gateway API entrypoints unless there is a concrete reason to publish something more broadly.

## Backup Strategy

- Velero covers cluster objects and workload metadata.
- Longhorn recurring backups cover the persistent volumes used by Open WebUI, LiteLLM PostgreSQL, and the Langfuse stateful components.
- There is no separate logical dump layer for the AI stack in this repo today because Langfuse spans PostgreSQL, ClickHouse, and MinIO, and the volume layer is the more complete recovery boundary.
