# Gas City

Gas City is the orchestration control workspace for the AI stack.

## What This Deployment Does

- Creates a persistent Gas City control pod in the `gascity` namespace
- Stores Gas City state on Longhorn-backed storage
- Boots a starter city with `GC_BEADS=file` to avoid the heavier Dolt/Beads stack for v1
- Grants the controller a dedicated service account with permission to manage
  pods/jobs/configmaps/secrets/services/PVCs inside the `agents` namespace

This is intentionally a pragmatic first deployment:

- Hermes is the human-facing gateway
- Gas City is the durable orchestration workspace
- Actual runner behavior can evolve later without replacing the control plane

## Current Limits

- Gas City includes a `gc dashboard` / `gc dashboard serve` command, but this
  deployment does not start or expose that web dashboard yet
- No public or internal dashboard route is exposed yet
- Hermes is not directly handing jobs to Gas City yet; this gets us the control
  pod, workspace, and Kubernetes permissions in place first

## Storage and Runtime Shape

- PVC: `gascity-data` (20Gi, Longhorn)
- Home directory: `/var/lib/gascity/home`
- City workspace: `/var/lib/gascity/city`
- Runtime image: `ghcr.io/gaahrdner/gascity-controller:main`
- Startup path:
  - `gc init /var/lib/gascity/city` on first boot
  - `GC_BEADS=file gc start`

## Image Publishing

The controller image is built from [image/Dockerfile](/Users/gaahrdner/Code/homelab/src/apps/services/ai/gascity/image/Dockerfile)
and published to GHCR by [.github/workflows/gascity-image.yaml](/Users/gaahrdner/Code/homelab/.github/workflows/gascity-image.yaml).

Published tags:

- `ghcr.io/gaahrdner/gascity-controller:main`
- `ghcr.io/gaahrdner/gascity-controller:sha-<git-sha>`

## Operations

### Check rollout

```bash
kubectl get application -n argocd gascity
kubectl get pods -n gascity
kubectl get rolebinding -n agents
```

### Check logs

```bash
kubectl logs -n gascity deployment/gascity --tail=100
```

### Exec into the controller pod

```bash
kubectl exec -it -n gascity deploy/gascity -- /bin/bash
cd /var/lib/gascity/city
gc version
gc session attach mayor
```

### Check dashboard support

```bash
kubectl exec -n gascity deploy/gascity -- gc dashboard --help
kubectl exec -n gascity deploy/gascity -- gc dashboard serve --help
```

To make the dashboard reachable, add a Service plus an internal HTTPRoute and
start `gc dashboard serve` in the pod, or run it manually for a short-lived
debug session. Keep this internal unless there is a concrete reason to expose it
more broadly.

## Sources

- [Gas City upstream repo](https://github.com/gastownhall/gascity)
- [Gas City releases](https://github.com/gastownhall/gascity/releases)
