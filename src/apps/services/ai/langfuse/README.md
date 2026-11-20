# Langfuse

Langfuse provides internal LLM observability and evaluation tooling.

## What This Deployment Does

- Exposes Langfuse at `http://langfuse.internal`
- Deploys Langfuse v2 web and worker pods via the `langfuse` Helm chart (`deploy: false` on bundled subcharts so chart upgrades stay clean and in-place)
- Deploys repo-managed in-cluster PostgreSQL 19, Valkey 8, standalone ClickHouse (with 7-day `system.*_log` TTLs), and SeaweedFS S3 under `k8s/`
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

## Metrics

- PostgreSQL metrics are exposed via a repo-managed `postgres-exporter`
- Redis/Valkey metrics are exposed via a repo-managed `redis-exporter`
- Langfuse web and worker are OTel-oriented; they do not currently expose a repo-wired Prometheus scrape endpoint
- ClickHouse and MinIO are not exporter-wired yet in this repo
