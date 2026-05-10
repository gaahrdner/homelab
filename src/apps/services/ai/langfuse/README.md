# Langfuse

Langfuse provides internal LLM observability and evaluation tooling.

## What This Deployment Does

- Exposes Langfuse at `http://langfuse.internal`
- Deploys Langfuse web and worker pods
- Deploys in-cluster PostgreSQL, Valkey, ClickHouse, and MinIO via the chart
- Sources all application and backing-service secrets from 1Password

## Required 1Password Items

Create these items in the `kubernetes` vault:

- `langfuse-core-secrets`
  - `salt`
  - `nextauth-secret`
  - `encryption-key`
- `langfuse-postgresql`
  - `postgres-password`
  - `password`
- `langfuse-redis`
  - `password`
- `langfuse-clickhouse`
  - `password`
- `langfuse-minio`
  - `root-user`
  - `root-password`

## Access

- UI: `http://langfuse.internal`

After first login, create Langfuse API keys in the UI if you want LiteLLM or
other apps to send traces into Langfuse.
