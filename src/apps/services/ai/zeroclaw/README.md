# ZeroClaw

ZeroClaw is an ultra-lightweight Rust AI agent runtime with a built-in web dashboard, gateway API, and workspace tools.

## What This Deployment Does

- Runs `ghcr.io/zeroclaw-labs/zeroclaw:v0.9.0` (distroless non-root Rust binary)
- Persists memory, SQLite state, and workspace files on a 5Gi Longhorn PVC (`zeroclaw-data`)
- Routes inference through the in-cluster LiteLLM gateway (`gx10-fast` by default)
- Exposes the bundled web dashboard and gateway at `http://zeroclaw.internal`

## Required 1Password Items

Uses the existing `litellm-master-key` item in the `kubernetes` vault (`mbn7rk3d5gfgofrv3a2zt2tdoe`, field `master-key`).

## Access

- Dashboard & Gateway: `http://zeroclaw.internal`
- Health check: `http://zeroclaw.internal/health`

## Notes

- Keep `replicas: 1` (`strategy: Recreate`) because ZeroClaw uses a local SQLite store on its RWO PVC.
- To require device pairing on the web UI, set `require_pairing = true` in `k8s/configmap.yaml` and fetch a paircode via `kubectl exec -n zeroclaw deploy/zeroclaw -- zeroclaw gateway get-paircode --new`.
