# AI Services

This directory is the internal and experimental AI tier for the homelab.

## Scope

- `litellm`: internal model gateway (`http://litellm.internal`)
- `open-webui`: internal chat UI (`http://open-webui.internal`)
- `hermes`: always-on chat/API/Signal gateway (`http://hermes.internal`)
- `kagent`: Kubernetes-native CRD agent platform (`http://kagent.internal`)
- `zeroclaw`: lightweight Rust agent runtime and dashboard (`http://zeroclaw.internal`)

## Expectations

- These apps are important, but they are not in the same stability class as core platform services like networking, storage, secrets, or ArgoCD itself.
- Prefer changes here over changes to shared platform infrastructure when experimenting with agent tooling.
- Keep external exposure conservative. Default to internal DNS and Gateway API entrypoints unless there is a concrete reason to publish something more broadly.

## Backup Strategy

- Velero covers cluster objects and workload metadata.
- Longhorn recurring backups cover the persistent volumes used by Open WebUI, LiteLLM PostgreSQL, Hermes, kagent PostgreSQL, and ZeroClaw.
