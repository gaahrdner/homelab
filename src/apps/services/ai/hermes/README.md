# Hermes

Hermes is the always-on remote gateway for the AI stack.

## What This Deployment Does

- Runs the official `nousresearch/hermes-agent` container in gateway mode
- Persists Hermes state in a Longhorn-backed volume mounted at `/opt/data`
- Seeds Hermes with a starter `config.yaml` that points model traffic at LiteLLM
- Exposes the Hermes dashboard at `http://hermes.internal`
- Keeps the Hermes API available in-cluster on port `8642`

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

## Optional Signal 1Password Item

Create this item in the `kubernetes` vault when you are ready to enable Signal:

- `hermes-signal`
  - `SIGNAL_ACCOUNT`
  - `SIGNAL_ALLOWED_USERS`
  - `SIGNAL_HOME_CHANNEL`
  - optional: `SIGNAL_GROUP_ALLOWED_USERS`

Hermes uses the LiteLLM master key as its OpenAI-compatible API key so it can
reach the internal alias table at `http://litellm.internal/v1`.

## Notes

- The seeded Hermes config defaults to the local `qwen-exec` alias through LiteLLM.
- Premium Together aliases are intended as explicit escalation lanes, not the default chat path.
- Signal is scaffolded in-cluster through a companion `signal-cli` deployment.
- Hermes only enables the Signal adapter after the optional `hermes-signal`
  secret exists, so the base gateway stays healthy before pairing.
- The Hermes dashboard is published only on the private `*.internal` route.
- The OpenAI-compatible API currently stays in-cluster so browser access and
  API access do not share the same hostname.

## Access

- Hermes API: `http://hermes.hermes.svc.cluster.local:8642`
- Dashboard: `http://hermes.internal`
- Signal daemon: `http://signal-cli.hermes.svc.cluster.local:8080`

## Signal Pairing

1. Create the `hermes-signal` item in 1Password with your phone number in
   E.164 format, for example `+15551234567`.
2. Wait for the `signal-cli` pod to start.
3. Link the pod as a secondary device:

```bash
kubectl exec -it -n hermes deploy/signal-cli -- signal-cli link -n hermes-signal
```

4. In Signal on your iPhone:

```text
Settings -> Linked devices -> Link new device
```

5. Scan the QR code from the terminal.
6. Message your own number in Signal using "Note to Self".

Hermes' Signal docs say this self-chat flow works automatically when
`SIGNAL_ACCOUNT` matches your phone number.

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
