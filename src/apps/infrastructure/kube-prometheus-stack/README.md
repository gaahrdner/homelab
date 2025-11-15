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
- **Credentials**: admin / (password from 1Password)
  - **Setup Required**: Create item in 1Password kubernetes vault:
    - Item name: `grafana-admin-credentials`
    - Fields: `username` (admin), `password` (your secure password)

### Alertmanager
- **Storage**: 2Gi Longhorn PVC
- **Configuration**: Default alert rules enabled (25+ rule groups)
- **Notification Channels**: Not configured
  - Alerts are generated but not sent anywhere
  - To add notifications, configure Alertmanager with Slack, email, Discord, etc.
  - Configuration goes in `alertmanager.config` section of values

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

## Automatic Metrics Discovery

### ServiceMonitors
The stack automatically discovers ServiceMonitors from all namespaces. Currently monitored:
- Cilium (agent + operator)
- Longhorn
- cert-manager
- ArgoCD (server, controller, repo-server)
- external-dns
- Cloudflared
- Loki and Promtail

### PodMonitors (Auto-Discovery)
A cluster-wide PodMonitor automatically scrapes metrics from ANY pod with these annotations:

```yaml
metadata:
  annotations:
    prometheus.io/scrape: "true"    # Enable scraping (required)
    prometheus.io/port: "8080"      # Metrics port (required)
    prometheus.io/path: "/metrics"  # Metrics path (optional, default: /metrics)
```

**Example - Deploying a New App with Auto-Discovery:**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  template:
    metadata:
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "9090"
        prometheus.io/path: "/metrics"  # optional
    spec:
      containers:
        - name: app
          image: my-app:latest
          ports:
            - containerPort: 9090
              name: metrics
```

**That's it!** Metrics are scraped automatically within 30 seconds. No ServiceMonitor needed.

**Labels Added Automatically:**
- `namespace`: Pod's namespace
- `pod`: Pod name
- `container`: Container name
- `node`: Node name (urd, verdandi, or skuld)
- `app`: From `app.kubernetes.io/name` label
- `version`: From `app.kubernetes.io/version` label
- `component`: From `app.kubernetes.io/component` label

## Access

- **Grafana UI**: http://grafana.internal or via LoadBalancer IP
- **Prometheus UI**: Port-forward to `kube-prometheus-stack-prometheus:9090`
- **Alertmanager UI**: Port-forward to `kube-prometheus-stack-alertmanager:9093`

## Notes

- ServerSideApply=true required in ArgoCD to handle large Prometheus CRDs
- Default dashboards included for Kubernetes, nodes, and all components
