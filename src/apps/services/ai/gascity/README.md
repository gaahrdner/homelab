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

- The dashboard is published internally at `http://gascity.internal`
- DNS-free fallback access is available at `http://192.168.0.203/`
- The supervisor API is routed on the same host under `/v0` and `/health`
- The supervisor API allows mutations so the dashboard can create convoys and
  operate the city; keep the route internal-only unless an auth layer is added
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
  - `gc dashboard serve --city /var/lib/gascity/city --port 8080 --api http://gascity.internal`
  - `gc dashboard serve --city /var/lib/gascity/city --port 8081 --api http://192.168.0.203`

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
curl -I -H 'Host: gascity.internal' http://192.168.0.203/
curl -I -H 'Host: gascity.internal' http://192.168.0.203/health
curl -I http://192.168.0.203/
```

The preferred browser entrypoint is `http://gascity.internal`. If a browser does
not resolve `.internal`, use `http://192.168.0.203/`. Keep this internal unless
there is a concrete reason to expose it more broadly.

## Sources

- [Gas City upstream repo](https://github.com/gastownhall/gascity)
- [Gas City releases](https://github.com/gastownhall/gascity/releases)
