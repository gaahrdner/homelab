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
- UniFi DNS server: `192.168.0.1/32`
- Internal Gateway API LoadBalancer IP: `192.168.0.203/32`

The `Connector` advertises the Kubernetes service and pod ranges plus two
targeted LAN `/32` routes:

- `192.168.0.1/32` so tailnet clients can query the UniFi DNS server directly
- `192.168.0.203/32` so the same internal Gateway API hostname targets work
  remotely without advertising the entire LAN

This keeps the access model consistent:

- on LAN: `*.internal` resolves through UniFi and routes directly
- on tailnet: `*.internal` resolves through Tailscale split DNS to UniFi and
  reaches the internal gateway over the advertised `/32`

Examples that should work the same on and off LAN once Tailscale DNS is
configured:

- `http://ghostfolio.internal`
- `http://keeper.internal`
- `http://grafana.internal`

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
    "10.244.0.0/16": ["tag:k8s"],
    "192.168.0.1/32": ["tag:k8s"],
    "192.168.0.203/32": ["tag:k8s"]
  }
}
```

## Required Tailscale DNS Settings

To make the same `*.internal` URLs work remotely, add split DNS in the
Tailscale admin console:

- Domain: `internal`
- Nameserver: `192.168.0.1`

That tells tailnet clients to resolve `ghostfolio.internal`,
`keeper.internal`, and similar names against the UniFi DNS server over the
advertised `/32` route instead of relying on local LAN DNS.

## Verification

After ArgoCD syncs:

```bash
kubectl --context admin@norns get pods -n tailscale
kubectl --context admin@norns get connector -n tailscale
```

Expected state:

- `tailscale-operator` pod is `Running`
- `norns-cluster-routes` shows `ConnectorCreated`
- The Tailscale admin console shows a connector device advertising:
  - `10.96.0.0/12`
  - `10.244.0.0/16`
  - `192.168.0.1/32`
  - `192.168.0.203/32`
- Tailscale DNS settings include split DNS for `internal` via `192.168.0.1`

Linux tailnet clients must accept subnet routes explicitly. Other clients accept routes by default.
