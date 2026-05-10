# Tailscale

Tailscale is deployed in-cluster using the official Kubernetes operator and a single `Connector` that acts as the subnet router for the Kubernetes network.

This is the right model for this homelab:

- One managed Tailscale footprint instead of enrolling all three Talos nodes separately
- GitOps-managed config instead of ad hoc auth keys on nodes
- Direct tailnet access to cluster-only IP ranges

## What This App Advertises

Verified against the live `norns` cluster on May 10, 2026:

- Service CIDR: `10.96.0.0/12`
- Pod CIDR aggregate: `10.244.0.0/16`

The `Connector` advertises both ranges so tailnet clients can reach ClusterIP services, pod IPs, and existing LAN-routed `.internal` entrypoints when needed.

## Required 1Password Item

Before syncing, add a `tailscale-operator-oauth` item to the 1Password `kubernetes` vault with these fields:

- `client_id`
- `client_secret`

Create the OAuth client in Tailscale with write scopes for:

- `Devices Core`
- `Auth Keys`
- `Services`

## Required Tailnet Policy

The operator uses `tag:k8s-operator` and the connector uses `tag:k8s` by default. Ensure the operator can create connector devices and auto-approve the cluster routes.

Example policy additions:

```json
"tagOwners": {
  "tag:k8s-operator": [],
  "tag:k8s": ["tag:k8s-operator"]
},
"autoApprovers": {
  "routes": {
    "10.96.0.0/12": ["tag:k8s"],
    "10.244.0.0/16": ["tag:k8s"]
  }
}
```

## Verification

After ArgoCD syncs:

```bash
kubectl --context admin@norns get pods -n tailscale
kubectl --context admin@norns get connector -n tailscale
```

Expected state:

- `tailscale-operator` pod is `Running`
- `norns-cluster-routes` shows `ConnectorCreated`
- The Tailscale admin console shows a connector device advertising `10.96.0.0/12` and `10.244.0.0/16`

Linux tailnet clients must accept subnet routes explicitly. Other clients accept routes by default.
