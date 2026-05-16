# Ghostfolio

Self-hosted deployment of [Ghostfolio](https://ghostfol.io/), an open-source
portfolio tracker for stocks, ETFs, and crypto.

## What This Deployment Does

- Exposes Ghostfolio at `http://ghostfolio.internal`
- Runs the upstream `ghostfolio/ghostfolio:3.3.0` image
- Provides in-cluster PostgreSQL 17 and Redis 8 with Longhorn-backed storage
- Stores all required app, database, and Redis secrets in the 1Password
  `kubernetes` vault
- Automatically scrapes PostgreSQL and Redis metrics via the cluster-wide
  PodMonitor

Ghostfolio is a tracker and analytics app, not a broker integration or managed
trading system. You still create the initial admin account yourself in the UI
after the first successful startup.

## Required 1Password Items

Before deploying, add these items to the `kubernetes` vault so the 1Password
operator can sync them into Kubernetes Secrets.

### 1. `ghostfolio-app-secrets`

Application signing secrets.

```text
Fields:
  - ACCESS_TOKEN_SALT (password): Generate with `openssl rand -base64 32`
  - JWT_SECRET_KEY (password): Generate with `openssl rand -base64 32`
```

### 2. `ghostfolio-postgresql`

Database credentials for the `ghostfolio` PostgreSQL user.

```text
Fields:
  - password (password): PostgreSQL password for the ghostfolio user
```

### 3. `ghostfolio-redis`

Redis authentication.

```text
Fields:
  - redis-password (password): Redis password
```

## Access

- Internal URL: `http://ghostfolio.internal`
- Service DNS: `ghostfolio.ghostfolio.svc.cluster.local:3333`

External-DNS will create the `ghostfolio.internal` record automatically from
the HTTPRoute.

## Deployment

Once the 1Password items exist, ArgoCD can sync the app normally:

```bash
git add src/apps/services/ghostfolio
git commit -m "feat: add ghostfolio investment tracker"
git push
```

ArgoCD will reconcile automatically within about 3 minutes, or you can force a
sync manually.

Useful checks:

```bash
kubectl get application -n argocd ghostfolio
kubectl get pods -n ghostfolio
kubectl get httproute -n ghostfolio
```

## First Login

1. Browse to `http://ghostfolio.internal`
2. Click `Get Started`
3. Create the first user account

Per the upstream docs, the first user created in a fresh deployment becomes the
`ADMIN` user.

## Metrics

This repo scrapes Ghostfolio's supporting datastores automatically:

- PostgreSQL metrics on port `9187`
- Redis metrics on port `9121`

The Ghostfolio application itself does not expose a Prometheus scrape endpoint
in this deployment today.

## Operations

Check the app status:

```bash
kubectl logs -n ghostfolio deployment/ghostfolio --tail=100
kubectl get httproute ghostfolio -n ghostfolio -o yaml
curl -I http://ghostfolio.internal/api/v1/health
```

Check the datastores:

```bash
kubectl logs -n ghostfolio statefulset/ghostfolio-postgresql --tail=100
kubectl logs -n ghostfolio statefulset/ghostfolio-redis --tail=100
```

## Notes

- `ROOT_URL` is set to `http://ghostfolio.internal` to match the cluster's
  internal Gateway API entrypoint.
- If you later want richer market-data quotas, add a separate 1Password-backed
  API key and wire it into the deployment explicitly instead of hardcoding it.

## References

- [Ghostfolio upstream](https://ghostfol.io/)
- [Ghostfolio GitHub repository](https://github.com/ghostfolio/ghostfolio)
