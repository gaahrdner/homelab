# LiteLLM

LiteLLM is deployed as the cluster's internal AI gateway.

## What This Deployment Does

- Exposes LiteLLM at `http://litellm.internal`
- Persists gateway state in PostgreSQL on Longhorn storage
- Reads the gateway master key from 1Password
- Sends proxy traces to the self-hosted Langfuse deployment
- Targets the split-mode local endpoints:
- `qwen-exec` / `qwen-review` -> `http://192.168.0.131:8000/v1`
    - current upstream model: `batsclamp/Huihui-Qwen3.6-35B-A3B-abliterated-FP8`
    - `qwen-exec` injects `chat_template_kwargs.enable_thinking=false`
    - `qwen-review` leaves thinking on by default
  - `ds4-plan` / `ds4-review` -> `http://192.168.0.123:8000/v1`
- Adds Together-backed escalation aliases for the "mayor" and hard-code lanes once `litellm-together` exists

## Required 1Password Items

Create these items in the `kubernetes` vault:

- `litellm-master-key`
  - `master-key`
- `litellm-postgresql`
  - `postgres-password`
  - `password`
- `litellm-together`
  - `TOGETHER_API_KEY`
- `langfuse-project-api-keys`
  - `LANGFUSE_PUBLIC_KEY`
  - `LANGFUSE_SECRET_KEY`

## Model Aliases

This repo now configures a small role-based model table:

| Alias | Backend | Role |
|---|---|---|
| `qwen-exec` | local uncensored Qwen 3.6 35B A3B FP8 (`batsclamp/Huihui-Qwen3.6-35B-A3B-abliterated-FP8`) | default executor |
| `qwen-review` | local uncensored Qwen 3.6 35B A3B FP8 (`batsclamp/Huihui-Qwen3.6-35B-A3B-abliterated-FP8`) | same local backend, but callers should enable reasoning for review turns |
| `ds4-plan` | local DeepSeek V4 Flash via `ds4` | local planner / long-context synthesizer |
| `ds4-review` | local DeepSeek V4 Flash via `ds4` | local reviewer / second opinion |
| `together-mayor` | Together `moonshotai/Kimi-K2.6` | premium planner / arbiter / escalation lane |
| `together-hardcode` | Together `zai-org/GLM-5.1` | hardest coding and long-horizon implementation tasks |

## Exact Secret Values

No local upstream secret values are required for the current split-mode setup.
The local endpoints are hardcoded in the ConfigMap because they are not secrets.
LiteLLM still wants an upstream `api_key` field for OpenAI-compatible backends,
so the local aliases use a literal placeholder value `dummy`.

The Together aliases are different: create the `litellm-together` 1Password
item with a `TOGETHER_API_KEY` field before relying on `together-mayor` or
`together-hardcode`.

## Routing Policy

- Use `qwen-exec` for the normal local execution loop.
- Use `qwen-review` for review or recovery turns, with reasoning enabled in the request.
- Use `ds4-plan` when you want an always-on local planner and long-context lane.
- Use `ds4-review` when you want a local second opinion before leaving the homelab.
- Use `together-mayor` when the workflow needs high-confidence planning, arbitration, or final judgment.
- Use `together-hardcode` for the hardest codegen / repair tasks that justify a premium escalation.

## Escalation Policy

The intended policy is:

- local first with `qwen-exec`
- local retry / second opinion with `ds4-review`
- premium escalation only when the task stalls, remains ambiguous, or needs a
  higher-confidence judgment call

## Request Defaults

- `qwen-exec`
  - `chat_template_kwargs.enable_thinking=false`
- `qwen-review`
  - `chat_template_kwargs.enable_thinking=true`
  - `chat_template_kwargs.preserve_thinking=true`
- `ds4-plan`
  - `model=deepseek-chat` for non-thinking control turns
  - `model=deepseek-v4-flash` for thinking/planning turns

Together currently exposes an OpenAI-compatible Chat Completions surface, not
the OpenAI Responses API. Keep the Together aliases for explicit escalation
turns rather than assuming every agent runtime can transparently swap to them.

LiteLLM aliases alone do not toggle Qwen reasoning. Callers should set those request
fields explicitly.

## Access

- LiteLLM endpoint: `http://litellm.internal`
- OpenAI-compatible base URL: `http://litellm.internal/v1`

## Metrics

- LiteLLM proxy metrics are exposed on `/metrics`
- LiteLLM PostgreSQL metrics are exposed via the `postgres-exporter` sidecar
- Both are scraped through the cluster-wide auto-discovery `PodMonitor`

## Tracing

- LiteLLM exports traces directly to the in-cluster Langfuse service
- The Langfuse project API keys are sourced from 1Password

## Layout

- `k8s/configmap.yaml`: LiteLLM proxy config
- `k8s/postgres.yaml`: backing PostgreSQL
- `k8s/deployment.yaml`: gateway deployment
- `k8s/httproute.yaml`: internal DNS/Gateway API exposure
