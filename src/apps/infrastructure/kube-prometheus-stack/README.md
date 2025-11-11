# kube-prometheus-stack

Complete monitoring stack with Prometheus, Grafana, and Alertmanager.

## Installation

Helm chart v70.0.0 managed by ArgoCD with ServerSideApply for large CRDs.

## Configuration

### Prometheus
- **Retention**: 7 days (time) / 15GB (size)
- **Storage**: 20Gi Longhorn PVC
- **ServiceMonitor Discovery**: All namespaces (no label filtering)
- **WAL Compression**: Enabled

### Grafana
- **Access**: LoadBalancer + grafana.internal
- **Storage**: 5Gi Longhorn PVC
- **Default Credentials**: admin/admin (change after first login)

### Alertmanager
- **Storage**: 2Gi Longhorn PVC
- **Configuration**: Default rules enabled

## Components

- **Prometheus Operator**: Manages Prometheus/Alertmanager instances
- **Prometheus**: Metrics collection and storage
- **Grafana**: Visualization and dashboards
- **Alertmanager**: Alert routing and notifications
- **node-exporter**: Node-level metrics
- **kube-state-metrics**: Kubernetes object state metrics

## Dependencies

- Longhorn (for PVCs)
- Cilium L2 pool (for Grafana LoadBalancer)
- Gateway (for grafana.internal)

## ServiceMonitors

The stack automatically discovers ServiceMonitors from all namespaces. Enabled services:
- Cilium (agent + operator)
- Longhorn (manual ServiceMonitor)
- cert-manager
- ArgoCD (server, controller, repo-server)
- external-dns

## Access

- **Grafana UI**: http://grafana.internal or via LoadBalancer IP
- **Prometheus UI**: Port-forward to `kube-prometheus-stack-prometheus:9090`
- **Alertmanager UI**: Port-forward to `kube-prometheus-stack-alertmanager:9093`

## Notes

- ServerSideApply=true required in ArgoCD to handle large Prometheus CRDs
- Default dashboards included for Kubernetes, nodes, and all components
