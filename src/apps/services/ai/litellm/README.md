# LiteLLM

LiteLLM is deployed as the cluster's internal AI gateway.

## What This Deployment Does

- Exposes LiteLLM at `http://litellm.internal`
- Persists gateway state in PostgreSQL on Longhorn storage
- Reads the gateway master key and vLLM upstream settings from 1Password
- Targets the GX10 head node at `http://192.168.0.131:8000/v1`

## Required 1Password Items

Create these items in the `kubernetes` vault:

- `litellm-master-key`
  - `master-key`
- `litellm-postgresql`
  - `postgres-password`
  - `password`
- `litellm-vllm-upstreams`
  - `VLLM_1_API_BASE`
  - `VLLM_1_API_KEY`

## Important Note

This repo configures a single LiteLLM model alias named `vllm` and points it at
the GX10 head node.

For requests to work, the upstream vLLM service must either:

- expose a served model name that matches `vllm`, or
- be updated later in this repo so LiteLLM forwards the correct upstream model name

Until the vLLM side is finalized, LiteLLM may be healthy but unable to complete
requests successfully.

## Access

- LiteLLM endpoint: `http://litellm.internal`
- OpenAI-compatible base URL: `http://litellm.internal/v1`

## Layout

- `k8s/configmap.yaml`: LiteLLM proxy config
- `k8s/postgres.yaml`: backing PostgreSQL
- `k8s/deployment.yaml`: gateway deployment
- `k8s/httproute.yaml`: internal DNS/Gateway API exposure
