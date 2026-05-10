# Tailscale

Tailscale is deployed in-cluster using the official Kubernetes operator, a single `Connector` that acts as the subnet router for the Kubernetes network, and a shared ingress `ProxyGroup` for HA Tailscale-published Services.

This is the right model for this homelab:

- One managed Tailscale footprint instead of enrolling all three Talos nodes separately
- GitOps-managed config instead of ad hoc auth keys on nodes
- Direct tailnet access to cluster-only IP ranges
- Shared Tailscale Services instead of one standalone tailnet machine per exposed workload Service

## What This App Advertises

Verified against the live `norns` cluster on May 10, 2026:

- Service CIDR: `10.96.0.0/12`
- Pod CIDR aggregate: `10.244.0.0/16`

The `Connector` advertises both ranges so tailnet clients can reach ClusterIP services and pod IPs when needed.

## HA Service Exposure

Repo-managed workload `Service` resources that should appear in Tailscale use:

- `tailscale.com/expose: "true"`
- `tailscale.com/proxy-group: "norns-ingress"`

The `ProxyGroup` keeps those Services on a shared HA proxy pool so they show up as Tailscale Services instead of individual Machines.

## Required 1Password Item

Before syncing, add a `tailscale-operator-oauth` item to the 1Password `kubernetes` vault with these fields:

- `client_id`
- `client_secret`

Create the OAuth client in Tailscale with write scopes for:

- `Devices Core`
- `Auth Keys`
- `Services`

## Required Tailnet Policy

The operator uses `tag:k8s-operator` and the connector, `ProxyGroup`, and default Tailscale Services use `tag:k8s`. Ensure the operator can create connector devices, auto-approve the cluster routes, and let the `ProxyGroup` advertise Tailscale Services.

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
  },
  "services": {
    "tag:k8s": ["tag:k8s"]
  }
}
```

If you do not add `autoApprovers.services`, HA Tailscale Services on the `ProxyGroup` will not finish publishing.

## Verification

After ArgoCD syncs:

```bash
kubectl --context admin@norns get pods -n tailscale
kubectl --context admin@norns get connector -n tailscale
```

Expected state:

- `tailscale-operator` pod is `Running`
- `norns-cluster-routes` shows `ConnectorCreated`
- `norns-ingress` shows `ProxyGroupReady`
- The Tailscale admin console shows a connector device advertising `10.96.0.0/12` and `10.244.0.0/16`
- HA workload exposure shows up in the Tailscale `Services` tab instead of as one Machine per Service

Linux tailnet clients must accept subnet routes explicitly. Other clients accept routes by default.
