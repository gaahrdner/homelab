# Paperclip

Paperclip is deployed as an internal authenticated/private AI orchestration
workspace at `http://paperclip.internal`.

## Components

- `Deployment/paperclip`: official Paperclip server and React UI on port `3100`
- `StatefulSet/paperclip-postgresql`: dedicated PostgreSQL 17 database
- `PVC/paperclip-data`: Paperclip home, config, local files, and runtime state
- `HTTPRoute/paperclip`: internal Gateway API route for `paperclip.internal`

The Paperclip image is pinned to the current `latest` multi-arch digest:

```text
ghcr.io/paperclipai/paperclip@sha256:beb09c3e5e0fd372ab89f5761464b329c201d89bdd4d54b49ef58f7a0532e561
```

## Secrets

Create these items in the 1Password `kubernetes` vault before syncing:

- `paperclip-app-secrets`
  - `BETTER_AUTH_SECRET`: generated high-entropy secret
  - `PAPERCLIP_AGENT_JWT_SECRET`: generated high-entropy secret
- `paperclip-postgresql`
  - `password`: generated PostgreSQL password

The deployment reads the PostgreSQL password as a separate secret and URL-encodes
it before constructing `DATABASE_URL`, so normal generated 1Password passwords
are safe.

## Access

- UI/API: `http://paperclip.internal`
- Health: `http://paperclip.internal/api/health`
- In-cluster service: `http://paperclip.paperclip.svc.cluster.local:3100`

The service is only exposed through the internal Gateway. It is not published as
a Tailscale Service and does not have a hostless Gateway fallback because
`192.168.0.203/` is already reserved for Gas City.

## Operations

```bash
kubectl get application -n argocd paperclip
kubectl get pods -n paperclip
kubectl get onepassworditem -n paperclip
kubectl logs -n paperclip deployment/paperclip --tail=100
curl -I http://paperclip.internal/api/health
```

If the UI reports that no instance admin exists, generate a one-time bootstrap
invite from the running Paperclip pod:

```bash
kubectl exec -n paperclip deploy/paperclip -- \
  pnpm paperclipai auth bootstrap-ceo --config /paperclip/instances/default/config.json
```

## Backup Strategy

- Velero covers Kubernetes objects and ArgoCD application state.
- Longhorn recurring backups cover both the Paperclip data PVC and the
  PostgreSQL PVC.
- There is no separate logical PostgreSQL dump configured for Paperclip yet.

## Upstream

- [Paperclip GitHub](https://github.com/paperclipai/paperclip)
