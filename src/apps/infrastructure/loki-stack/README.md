# Loki Stack - Centralized Log Aggregation

## Overview

The Loki Stack provides centralized log aggregation for the entire cluster using Grafana Loki and Promtail. This enables:

- **Searchable Logs**: Query logs across all pods and namespaces from Grafana
- **Automatic Collection**: Every pod's logs are automatically scraped (zero configuration needed)
- **Correlation**: View logs alongside metrics in the same Grafana interface
- **Retention**: 7-day log retention (matches Prometheus retention)

## Components

### Loki (Log Storage Backend)
- **Namespace**: `loki-stack`
- **Storage**: 20Gi Longhorn PVC
- **Retention**: 7 days (168 hours)
- **Port**: 3100 (ClusterIP)
- **Metrics**: Exposed via ServiceMonitor

### Promtail (Log Collection Agent)
- **Deployment**: DaemonSet (runs on all 3 nodes)
- **Scrape Jobs**:
  1. **kubernetes-pods**: Automatically collects logs from ALL pods in the cluster
     - Adds labels: namespace, pod, container, node, app
     - No configuration needed for new workloads
  2. **Talos system logs**: Planned (requires Talos logging endpoint or forwarder)

### Grafana Datasource
- **Type**: Loki
- **URL**: `http://loki-stack:3100`
- **Auto-discovered**: ConfigMap with `grafana_datasource: "1"` label
- **Integration**: Automatically added to existing Grafana instance

## How It Works

### Automatic Pod Log Collection

When you deploy any application:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  template:
    spec:
      containers:
        - name: app
          image: my-image:latest
          # Logs written to stdout/stderr are automatically collected
```

**That's it!** No configuration needed. Logs appear in Grafana within seconds.

### Querying Logs in Grafana

1. Open Grafana at `http://grafana.internal`
2. Go to **Explore** → Select **Loki** datasource
3. Query examples:
   ```logql
   # All logs from a namespace
   {namespace="texasdust"}

   # Logs from a specific pod
   {pod="wordpress-7d9f8b5c4d-abc12"}

   # Search for error messages
   {namespace="texasdust"} |= "error"

   # Filter by container
   {namespace="monitoring", container="prometheus"}

   # Combine with metrics in dashboards
   ```

### Labels Applied to All Logs

- `namespace`: Kubernetes namespace
- `pod`: Pod name
- `container`: Container name within the pod
- `node`: Node where the pod is running (urd, verdandi, or skuld)
- `app`: Value from `app.kubernetes.io/name` label (if present)

## Storage and Retention

- **Log Storage**: 20Gi Longhorn volume (shared across 3 node replicas)
- **Retention Period**: 7 days (automatically cleaned up by compactor)
- **Compression**: Logs are compressed and indexed efficiently
- **Query Performance**: TSDB schema (v13) for fast queries

## Monitoring

- **Loki Metrics**: Scraped by Prometheus via ServiceMonitor
- **Promtail Metrics**: Scraped by Prometheus via ServiceMonitor
- **Dashboards**: Use Grafana's built-in Loki dashboards or create custom ones

## Resource Usage

**Loki:**
- Requests: 100m CPU, 256Mi RAM
- Limits: 500m CPU, 512Mi RAM

**Promtail (per node):**
- Requests: 50m CPU, 128Mi RAM
- Limits: 200m CPU, 256Mi RAM

## Troubleshooting

### Logs not appearing in Grafana

1. Check Promtail is running on all nodes:
   ```bash
   kubectl get pods -n loki-stack -l app.kubernetes.io/name=promtail
   ```

2. Check Promtail logs for errors:
   ```bash
   kubectl logs -n loki-stack -l app.kubernetes.io/name=promtail
   ```

3. Check Loki is healthy:
   ```bash
   kubectl get pods -n loki-stack -l app.kubernetes.io/name=loki
   kubectl logs -n loki-stack -l app.kubernetes.io/name=loki
   ```

4. Verify datasource in Grafana:
   - Go to Configuration → Data Sources → Loki
   - Click "Test" button (should show green success)

### High memory usage

If Loki uses too much memory:
- Reduce retention period in `application.yaml` (currently 168h)
- Reduce storage size if needed
- Check for log spam from applications

### Missing labels

If logs are missing expected labels:
- Check pod has the label defined (e.g., `app.kubernetes.io/name`)
- Labels are optional - not all applications set them

## Future Enhancements

- [ ] Add Talos system log collection (kernel, systemd services)
- [ ] Configure log-based alerts (e.g., alert on ERROR rate spikes)
- [ ] Add distributed tracing with Tempo (correlate logs → traces → metrics)
- [ ] Create custom Grafana dashboards for application logs
- [ ] Add log parsing pipelines for structured logs (JSON)

## References

- [Loki Documentation](https://grafana.com/docs/loki/latest/)
- [LogQL Query Language](https://grafana.com/docs/loki/latest/logql/)
- [Promtail Configuration](https://grafana.com/docs/loki/latest/clients/promtail/configuration/)
