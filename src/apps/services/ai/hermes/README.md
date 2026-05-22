# Hermes

Hermes is the always-on remote gateway for the AI stack.

## What This Deployment Does

- Runs the official `nousresearch/hermes-agent` container in gateway mode
- Persists Hermes state in a Longhorn-backed volume mounted at `/opt/data`
- Seeds Hermes with a starter `config.yaml` that points model traffic at LiteLLM
- Exposes the OpenAI-compatible Hermes API internally at `http://hermes.internal`
- Keeps the optional Hermes dashboard cluster-internal only on port `9119`

This deployment intentionally starts Hermes as the human-facing gateway layer,
not as the final repo-execution runtime. The coding/orchestration path is:

- Hermes for chat/API ingress
- Gas City for coordination
- LiteLLM for model routing
- GX10 + Together for inference

## Required 1Password Items

Create these items in the `kubernetes` vault:

- `hermes-core-secrets`
  - `API_SERVER_KEY`
- `litellm-master-key`
  - `master-key`

Hermes uses the LiteLLM master key as its OpenAI-compatible API key so it can
reach the internal alias table at `http://litellm.internal/v1`.

## Notes

- The seeded Hermes config defaults to the local `qwen-exec` alias through LiteLLM.
- Premium Together aliases are intended as explicit escalation lanes, not the default chat path.
- Signal is not enabled by default in this repo yet. Hermes supports it, but
  Signal requires an additional `signal-cli` runtime and pairing flow that is
  better added after the gateway itself is stable.
- The built-in Hermes dashboard is deliberately not published through Gateway
  API because upstream warns that it has no auth of its own.

## Access

- Hermes API: `http://hermes.internal`
- In-cluster service: `http://hermes.hermes.svc.cluster.local:8642`
- Dashboard: `http://hermes.hermes.svc.cluster.local:9119`

## Operations

### Check rollout

```bash
kubectl get application -n argocd hermes
kubectl get pods -n hermes
kubectl get httproute -n hermes
```

### Check logs

```bash
kubectl logs -n hermes deployment/hermes --tail=100
```

### Verify the internal API route

```bash
kubectl get httproute hermes -n hermes -o yaml
curl -I http://hermes.internal/health
```

## Sources

- [Hermes Agent upstream repo](https://github.com/NousResearch/hermes-agent)
- [Hermes Docker guide](https://github.com/NousResearch/hermes-agent/blob/main/website/docs/user-guide/docker.md)
- [Hermes API server guide](https://github.com/NousResearch/hermes-agent/blob/main/website/docs/user-guide/features/api-server.md)
