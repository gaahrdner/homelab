# Keeper

Self-hosted deployment of [Keeper.sh](https://www.keeper.sh/), an open-source
calendar sync service for Google, Outlook, iCloud, CalDAV, and ICS feeds.

## Architecture

This deployment uses the upstream `ghcr.io/ridafkih/keeper-services:2.9`
container, which bundles Keeper's web, API, cron, and worker processes into a
single pod. PostgreSQL and Redis run in-cluster as separate StatefulSets backed
by Longhorn volumes.

- **Application**: Keeper services image `2.9`
- **Database**: PostgreSQL 17 (10Gi)
- **Cache / queue**: Redis 7 (1Gi)
- **Storage**: Longhorn distributed storage
- **Access**: `http://keeper.internal` via Gateway API HTTPRoute + external-dns

`keeper-services` keeps the manifest surface smaller than running all of
Keeper's individual images, while still avoiding the all-in-one standalone
container that embeds its own database and Redis.

## Prerequisites

Before Argo CD syncs the workload, add these items to the 1Password
`kubernetes` vault:

### 1. `keeper-app-secrets`

Required runtime secrets.

```text
Fields:
  - BETTER_AUTH_SECRET (password): Generate with `openssl rand -base64 32`
  - ENCRYPTION_KEY (password): Generate with `openssl rand -base64 32`
```

### 2. `keeper-postgresql`

Database credentials for the `keeper` PostgreSQL user.

```text
Fields:
  - password (password): Strong PostgreSQL password
```

### 3. `keeper-redis`

Redis authentication.

```text
Fields:
  - redis-password (password): Strong Redis password
```

This baseline deployment does not wire Google or Microsoft OAuth yet. Keeper
still works for providers like ICS, iCloud, and generic CalDAV without those
credentials.

## Deployment

Once the 1Password items exist:

```bash
git add src/apps/services/keeper
git commit -m "feat: add keeper calendar sync service"
git push
```

Argo CD will pick up the new `Application` under `src/apps/` and sync it within
about 3 minutes.

## Access

- **Internal URL**: `http://keeper.internal`
- **Service DNS**: `keeper.keeper.svc.cluster.local:3000`
- **No Tailscale-published Service**: access is routed through the cluster
  subnet router and the existing internal Gateway

The deployment sets:

- `BETTER_AUTH_URL=http://keeper.internal`
- `TRUSTED_ORIGINS=http://keeper.internal`

If you later expose Keeper on a second hostname, update both values so
`better-auth` accepts that origin.

## Operations

### Check rollout

```bash
kubectl get application -n argocd keeper
kubectl get pods -n keeper
kubectl get httproute -n keeper
```

### Check logs

```bash
kubectl logs -n keeper deployment/keeper --tail=100
```

### Check the internal route

```bash
kubectl get httproute keeper -n keeper -o yaml
curl -I http://keeper.internal
```

### OAuth provider setup notes

Keeper's upstream docs currently require these scopes:

- **Google**: `calendar.events`, `calendar.calendarlist.readonly`,
  `userinfo.email`
- **Microsoft**: `Calendars.ReadWrite`, `User.Read`, `offline_access`

If you want Google or Microsoft destinations later, add a dedicated 1Password
item for those client IDs and secrets, then extend
[deployment.yaml](/Users/gaahrdner/Code/homelab/src/apps/services/keeper/k8s/deployment.yaml)
with the corresponding environment variables.

## Notes

- This deployment intentionally runs a single Keeper replica because the
  `keeper-services` image bundles the cron scheduler and worker into the same
  process group.
- Google and Microsoft OAuth are not enabled in the baseline manifests, so this
  first rollout is aimed at ICS, iCloud, and generic CalDAV integrations.
- PostgreSQL and Redis both expose Prometheus sidecar exporters and are
  discovered automatically by the cluster-wide PodMonitor.
- Keeper's optional MCP server is not enabled here. If you want it later, add a
  separate `keeper-mcp` deployment and wire `/mcp` through the web service as
  described upstream.

## Sources

- [Keeper.sh upstream site](https://www.keeper.sh/)
- [Keeper self-hosting README](https://github.com/ridafkih/keeper.sh)
