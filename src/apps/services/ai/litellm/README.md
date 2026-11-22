# LiteLLM

LiteLLM is deployed as the cluster's internal AI gateway.

## What This Deployment Does

- Runs from [configmap.yaml](k8s/configmap.yaml) backed by `litellm-postgresql` (`store_model_in_db: true`) so the LiteLLM Admin UI (`/ui`, `/v2/model/info`) and UI model edits work cleanly
- Exposes LiteLLM at `http://litellm.internal`
- Reads the gateway master key and PostgreSQL credentials from 1Password
- Exports Prometheus metrics on `/metrics` (and PostgreSQL metrics via `postgres-exporter` on `:9187`)

## Model Aliases

State as of commit `325d4cd`. All aliases use a literal placeholder upstream `api_key` because the local backends do not require auth; only the gateway master key matters for clients.

| Alias | Backend | Status |
|---|---|---|
| `gx10-coding` | geri:8000 — `nvidia/Qwen3.8-27B-NVFP4` (Coding Workhorse) | LIVE — verified completion (0.2s) |
| `gx10-fast` | freki:8000 — `thinkingmachines/Inkling-2-Mini` (Fast Chat/Reasoning/Vision) | LIVE — verified completion (0.1s) |
| `gx10-nemotron` | geri:8000 — `nvidia/NVIDIA-Nemotron-3.5-Super-VL-120B-A12B-NVFP4` | inert alternate — returns 404 until the backend swaps |
| `gx10-gemma4` | freki:8000 — `nvidia/Gemma-4-26B-A4B-NVFP4` | inert alternate — returns 404 until the backend swaps |
| `gx10-qwen38-next` | freki:8000 — `nvidia/Qwen3.8-Flash-Next-FP4-Local` (Linked TP=2) | inert alternate — returns 404 until the backend swaps |
| `gx10-glm53` | freki:8000 — `nvidia/GLM-5.3-Flash-FP4-Local` (Linked TP=2) | inert alternate — returns 404 until the backend swaps |
| `gx10-inkling-small` | freki:8000 — `thinkingmachines/Inkling-Small-NVFP4` (Linked TP=2) | inert alternate — returns 404 until the backend swaps |
| `gx10-image` | freki:8091 — `Qwen/Qwen-Image-2.1-Turbo` (Always-On image gen) | not yet smoke-probed (180s+ request); expects long generation latency |

How alternates load: each GX10 backend (`freki.internal:8000`/`geri.internal:8000`) serves exactly one model at a time. The web control panel at `http://freki.internal:8080` manages the Split Dual-Lane vs Linked TP=2 mode; swapping backends there is what makes an alternate alias answerable. Until the backend serves the model, the alias 404s. The configmap owns the full inventory so the swap is config-ready; do not remove the inert entries.

## Required 1Password Items

In the `kubernetes` vault (`mbn7rk3d5gfgofrv3a2zt2tdoe`):

- `litellm-master-key` (field `master-key`) — required; merged into the proxy env as `PROXY_MASTER_KEY`
- `litellm-postgresql` (fields `postgres-password`, `password`) — required for `litellm-postgresql` StatefulSet and `DATABASE_URL`
- `litellm-together` — present but **not wired into the config** (no Together-backed aliases in the current configmap)
- `litellm-vllm-upstreams` — present but unused by the current local-backend config

## Routing Policy

- `gx10-coding` — dedicated coding lane (geri)
- `gx10-fast` — fast chat/reasoning/vision lane (freki); default for agents
- `gx10-image` — image generation lane (freki:8091)

## Access

- LiteLLM endpoint: `http://litellm.internal`
- OpenAI-compatible base URL: `http://litellm.internal/v1`
- Auth header for clients: `Authorization: Bearer <master-key>` (master key is never committed; read from the `litellm-master-key` 1Password item)

## Metrics

- LiteLLM proxy metrics are exposed on `/metrics` and scraped through the cluster-wide auto-discovery `PodMonitor`

## Layout

- `k8s/configmap.yaml`: LiteLLM proxy config
- `k8s/postgres.yaml`: backing PostgreSQL 19 StatefulSet + `postgres-exporter`
- `k8s/deployment.yaml`: gateway deployment
- `k8s/httproute.yaml`: internal DNS/Gateway API exposure
- `k8s/service.yaml`: ClusterIP service
