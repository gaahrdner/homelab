# Logging Stack

This directory defines the cluster logging stack:

- `loki` from `grafana-community/helm-charts`
- `alloy` from `grafana/helm-charts`
- a Grafana datasource ConfigMap for the existing `kube-prometheus-stack` Grafana

## Deployment Model

- **Loki** runs in `Monolithic` mode with a single Longhorn-backed PVC
- **Alloy** runs as a single Deployment and tails pod logs through the Kubernetes API
- **Grafana** remains part of `kube-prometheus-stack` and picks up the Loki datasource via sidecar discovery

## Versions

- Loki chart `13.6.1` / app `3.7.1`
- Alloy chart `1.8.1` / app `v1.16.1`

## Notes

- This replaces the old unmanaged `loki-stack` install.
- Loki retention is set to `7d` with `10Gi` of Longhorn-backed storage.
- No application secrets are required for this stack.
