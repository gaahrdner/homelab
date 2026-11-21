# LiteLLM

LiteLLM is deployed as the cluster's internal AI gateway.

## What This Deployment Does

- Runs stateless from [configmap.yaml](k8s/configmap.yaml) (no PostgreSQL backing database)
- Exposes LiteLLM at `http://litellm.internal`
- Reads the gateway master key and upstream provider keys from 1Password
- Exports Prometheus metrics on `/metrics`
- Routes local aliases (`ds4-vision`, `ds4-plan`, `ds4-review`) to `http://192.168.0.123:8000/v1` and Together-backed escalation aliases (`together-mayor`, `together-hardcode`) once `litellm-together` exists

## Required 1Password Items

Create these items in the `kubernetes` vault (`mbn7rk3d5gfgofrv3a2zt2tdoe`):

- `litellm-master-key`
  - `master-key`
- `litellm-together`
  - `TOGETHER_API_KEY`

## Model Aliases

This repo now configures a small role-based model table:

| Alias | Backend | Role |
|---|---|---|
| `qwen-exec` | local uncensored Qwen 3.6 35B A3B FP8 (`batsclamp/Huihui-Qwen3.6-35B-A3B-abliterated-FP8`) | default executor |
| `qwen-review` | local uncensored Qwen 3.6 35B A3B FP8 (`batsclamp/Huihui-Qwen3.6-35B-A3B-abliterated-FP8`) | same local backend, but callers should enable reasoning for review turns |
| `ds4-plan` | local DeepSeek V4 Flash via `ds4` | local planner / long-context synthesizer |
| `ds4-review` | local DeepSeek V4 Flash via `ds4` | local reviewer / second opinion |
| `together-mayor` | LiteLLM `together_ai/moonshotai/Kimi-K2.6` | premium planner / arbiter / escalation lane |
| `together-hardcode` | LiteLLM `together_ai/zai-org/GLM-5.1` | hardest coding and long-horizon implementation tasks |

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

- LiteLLM proxy metrics are exposed on `/metrics` and scraped through the cluster-wide auto-discovery `PodMonitor`

## Layout

- `k8s/configmap.yaml`: LiteLLM proxy config
- `k8s/deployment.yaml`: stateless gateway deployment
- `k8s/httproute.yaml`: internal DNS/Gateway API exposure
