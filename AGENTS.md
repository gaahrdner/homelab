# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Working Principles

**CRITICAL - Read this first:**

1. **Think deeply before acting** - Don't rush. Understand the full context and implications before executing commands or making changes.

2. **Maintain a TODO list** - For any multi-step task, use the TodoWrite tool to track progress. Update it as you complete each step. This helps you stay organized and gives the user visibility.

3. **Atomic commits** - Complete each logical step fully before moving to the next. Don't leave things half-done. If something breaks, fix it before proceeding.

4. **Store everything in Git** - Never apply manifests directly from URLs. Download CRDs, Helm values, and configs to the repository first (under `src/kubernetes/` or `src/talos/`). This ensures reproducibility and GitOps principles.

5. **Keep documentation current** - After completing work, update CLAUDE.md, README.md, and any relevant mise tasks to reflect what was done and how to do it again.

6. **Don't be sycophantic** - Focus on technical accuracy and getting things right, not on praise or validation.

## Project Overview

This is a Kubernetes homelab cluster running on Talos Linux. The cluster is named "norns" and consists of three control plane nodes (urd, verdandi, skuld) that also run workloads.

**Current State**: Production cluster with ArgoCD managing applications via GitOps.

**Key Details:**
- **Cluster Name**: norns
- **Talos Version**: v1.11.5
- **Kubernetes Version**: v1.34.1
- **Control Plane Nodes**: urd (192.168.0.120), verdandi (192.168.0.121), skuld (192.168.0.122)
- **Control Plane Endpoint**: https://192.168.0.120:6443
- **Task Runner**: mise (configured in `.mise.toml`)

**Deployed Applications:**
- **Infrastructure**: Cilium L2 LoadBalancer, Longhorn distributed storage, external-dns (UniFi), Cloudflare Tunnel
- **Platform Services**: cert-manager (TLS), 1Password Connect (secrets), kube-prometheus-stack
- **Applications**: texasdust.org (WordPress nonprofit site, exposed via Cloudflare Tunnel)

## Common Commands

All cluster management is done through `mise` tasks. Run `mise tasks` to see all available commands.

### New Cluster Setup

**Required - 3 Commands:**

```bash
mise run gen-cluster          # Generate secrets + configs (NEW CLUSTER ONLY)
mise run init                 # Initialize cluster (apply + bootstrap + kubeconfig)
mise run setup-networking     # Setup Gateway API + Cilium CNI (with node reboots)
```

**That's it!** You now have a working Kubernetes cluster with Cilium networking.

**Optional - GitOps with ArgoCD:**

```bash
# First: Update src/bootstrap/argocd/root-app.yaml with your GitHub repo URL
mise run bootstrap-gitops     # Install ArgoCD (manages apps in src/apps/)
```

**After ArgoCD is installed:** All apps in `src/apps/` are auto-synced from Git. Just `git push` to deploy.

### Existing Cluster Updates
```bash
mise run update               # Regenerate configs (preserves secrets!)
mise run apply                # Apply configs to all nodes
mise run health               # Verify health
```

### Individual Node Operations
```bash
mise run apply-urd            # Apply config to urd only
mise run apply-verdandi       # Apply config to verdandi only
mise run apply-skuld          # Apply config to skuld only
```

### Cluster Operations
```bash
mise run health               # Check Talos + Kubernetes health
TALOS_IMAGE=<image> mise run upgrade  # Upgrade all nodes to new Talos version
NODE=<ip> mise run reset-node # Reset specific node (DESTRUCTIVE)
```

### Standard Kubernetes/Talos Commands
```bash
kubectl get nodes             # View cluster nodes
kubectl get pods -A           # View all pods
talosctl --nodes <ip> health  # Check node health
```

## Architecture

### Networking Stack

The cluster uses Cilium as the CNI with the following components:

- **Gateway API v1.2.1**: Modern ingress/routing (replaces traditional Ingress)
- **Cilium v1.18.3**: CNI with kube-proxy replacement, eBPF-based networking
- **Hubble**: Network observability (relay + UI)
- **Cilium L2 Announcements**: LoadBalancer IP advertisement via ARP (IP range: 192.168.0.200-253)

**CRITICAL: Network Setup Must Follow This Exact Order**

You CANNOT bootstrap a Kubernetes cluster without a working CNI. Therefore, the networking setup follows a specific sequence:

1. **Bootstrap cluster with default networking** - Talos provides Flannel CNI and kube-proxy out of the box
2. **Install Cilium alongside defaults** - Dual CNI state where both Flannel and Cilium run simultaneously
3. **Verify Cilium is working** - Ensure Cilium agents and Hubble are healthy
4. **Disable default CNI/kube-proxy** - Apply Talos config patch and reboot nodes
5. **Verify transition** - Confirm kube-proxy is gone and only Cilium remains

**DO NOT:**
- Try to disable the default CNI during initial cluster generation (`gen-config`)
- Apply the `cilium.yaml` patch before Cilium is installed and verified
- Skip verifying each step before proceeding to the next

**Automated Setup**:
The `mise run setup-networking` command handles all 5 steps automatically. It:
- Applies Gateway API CRDs from `src/bootstrap/gateway-api/`
- Installs Cilium via Helm using values from `src/bootstrap/cilium/values.yaml` (includes L2 announcements)
- Waits for Cilium to be ready
- Regenerates Talos configs with the `cilium.yaml` patch
- Applies configs and reboots all nodes to complete the transition
- Verifies kube-proxy removal

After `setup-networking`, you have a working cluster. LoadBalancer and application management is handled separately by ArgoCD (optional).

### DNS Management with External-DNS

External-DNS automatically manages internal DNS records in the UniFi Dream Router for LoadBalancer services and HTTPRoutes.

**Configuration:**
- **Provider**: UniFi webhook (v0.7.0)
- **Domain Filter**: Only manages `.internal` domains
- **Controller**: Dream Router at 192.168.0.1
- **Authentication**: API key from 1Password (vault: kubernetes, item: unifi-external-dns)

**How it works:**
1. External-DNS watches Services (LoadBalancer), Ingresses, and HTTPRoutes
2. For any resource with a `.internal` hostname, it creates DNS records in UniFi
3. Uses TXT records to track ownership (prefix: `external-dns-`, owner: `norns-cluster`)

**Example HTTPRoute with automatic DNS:**
```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: my-app
spec:
  hostnames:
    - myapp.internal  # External-DNS will create this A record
  parentRefs:
    - name: internal
      namespace: gateway
```

**Verification:**
```bash
# Check external-dns logs
kubectl logs -n external-dns -l app.kubernetes.io/name=external-dns -c external-dns

# Test DNS resolution (from any machine using UniFi DNS)
nslookup myapp.internal
```

See `src/apps/infrastructure/external-dns/README.md` for detailed configuration and troubleshooting.

### GitOps with ArgoCD (Optional)

ArgoCD is **optional** but recommended for automatic application management. Once installed via `mise run bootstrap-gitops`, it manages all resources in `src/apps/`.

**Directory Structure:**
```
src/
├── bootstrap/          # One-time setup (mise manages these)
│   ├── gateway-api/    # CRDs applied during networking setup
│   ├── cilium/         # CNI Helm values
│   └── argocd/         # ArgoCD installation + root app
├── apps/               # Everything ArgoCD manages (if installed)
│   ├── infrastructure/ # Cluster-level (LoadBalancer pools, storage)
│   └── services/       # Everything else (cert-manager, apps, etc.)
└── talos/              # Talos machine configs
```

**Workflow with ArgoCD:**
1. Add/modify manifests in `src/apps/`
2. `git commit && git push`
3. ArgoCD syncs automatically (or immediately via UI)

**Why separate bootstrap/ from apps/?**
- **bootstrap/**: Infrastructure requiring special handling (CNI transitions, node reboots, ArgoCD itself)
- **apps/**: Everything else that ArgoCD can safely manage

**Without ArgoCD**: You can still use the cluster normally and apply manifests with `kubectl apply` manually.

### Configuration Management

The cluster uses a layered patching system for machine configurations:

1. **Base Configuration** (`controlplane.yaml`): Generated from patches, not edited directly
2. **Shared Patches** (`src/talos/patches/`):
   - `image.yaml` - Custom Talos installer image from Image Factory (includes extensions)
   - `scheduling.yaml` - Enables pod scheduling on control planes (`allowSchedulingOnControlPlanes: true`)
   - `kubelet.yaml` - Kubelet settings (max-pods: 300)
   - `cilium.yaml` - Disables default CNI and kube-proxy (applied during networking setup)
3. **Node-Specific Patches** (`src/talos/patches/network-*.yaml`):
   - Sets unique hostname for each node (urd, verdandi, skuld)

**Final Configs**: `controlplane-{urd,verdandi,skuld}.yaml` are generated by applying base + node-specific patches.

### Talos Image Customization

This cluster uses a custom Talos image built via the Talos Image Factory with system extensions.

**Workflow**:
1. Edit `src/talos/extensions.yaml` to add/remove extensions
2. Run `mise run generate-schematic` to generate a schematic ID
3. Update `src/talos/patches/image.yaml` with the new installer path
4. Run `mise run update` to regenerate configs with new image

**Current Extensions**:
- `siderolabs/gvisor` - Container runtime sandbox
- `siderolabs/i915` - Intel GPU drivers
- `siderolabs/intel-ucode` - Intel microcode updates
- `siderolabs/iscsi-tools` - iSCSI initiator tools (for Longhorn storage)
- `siderolabs/util-linux-tools` - Additional Linux utilities

### Secrets Management

**Talos Cluster Secrets**

**CRITICAL**: `secrets.yaml` contains cluster CA certificates and keys.

- This file is generated ONCE during initial cluster setup (`mise run gen-secrets`)
- It is preserved across config regenerations (`mise run update` reuses existing secrets)
- Regenerating this file will DESTROY the existing cluster
- The gen-secrets task will refuse to run if secrets.yaml already exists

**Application Secrets (1Password)**

The cluster uses 1Password Connect to sync secrets from 1Password vaults into Kubernetes:

- All application passwords and sensitive values are stored in 1Password
- 1Password Connect operator syncs them as Kubernetes `OnePasswordItem` resources
- Applications reference secrets via standard Kubernetes `Secret` objects
- When adding new secrets, first create them in the 1Password "kubernetes" vault, then reference them in manifests

**Setup Requirements:**

Before deploying 1Password Connect, you must create bootstrap secrets in `secrets/`:

1. **onepassword-credentials.yaml** - Connect server credentials
   ```bash
   # CRITICAL: Must be DOUBLE base64-encoded
   # Reason: K8s decodes when injecting as env var, but Connect expects base64
   cat 1password-credentials.json | base64 | tr -d '\n' | base64 > creds.txt
   # Then use creds.txt content in the secret yaml
   ```

2. **onepassword-token.yaml** - Access token for the operator
   ```bash
   # This is NOT base64-encoded, use raw token value
   kubectl create secret generic onepassword-token \
     --from-literal=token="YOUR_TOKEN" \
     --namespace onepassword --dry-run=client -o yaml
   ```

See `secrets/secrets.example.yaml` for detailed setup instructions.

**IMPORTANT**: Never hardcode secrets in manifests. Always use 1Password vault references.

### Configuration Regeneration Flow

When you modify patches or need to update configs:

1. **For new clusters**: `mise run gen-cluster` (generates secrets + configs)
2. **For existing clusters**: `mise run update` (regenerates configs, keeps secrets)

Both flows end with the same result: updated `controlplane-{node}.yaml` files ready to apply.

### Node Bootstrap Process

Initial cluster setup (`mise run init`):
1. Applies machine configs to all three nodes (insecure mode, before certs exist)
2. Configures talosctl endpoints for all three IPs
3. Bootstraps etcd on urd (first node)
4. Waits 30s for cluster initialization
5. Generates kubeconfig from urd
6. Installs talosconfig → `~/.talos/config` and kubeconfig → `~/.kube/config`

## External Access with Cloudflare Tunnel

The cluster uses Cloudflare Tunnel (cloudflared) to expose services to the public internet without opening firewall ports.

**Architecture**: Locally-managed tunnels (configuration in Git, not dashboard-managed)

**Setup Process**:
1. Create tunnel locally: `cloudflared tunnel create <name>` generates credentials JSON
2. Store credentials JSON in 1Password (kubernetes vault)
3. Create DNS CNAME: `<domain>` → `<tunnel-id>.cfargotunnel.com` (Cloudflare dashboard)
4. Deploy cloudflared to Kubernetes with:
   - OnePasswordItem: syncs credentials from 1Password
   - ConfigMap: tunnel ID + ingress rules (hostname → service mappings)
   - Deployment: 2 replicas of cloudflared pods
   - ServiceMonitor: Prometheus metrics

**Key Points**:
- Tunnel ID is public (visible in dashboard), credentials are secret (stored in 1Password)
- DNS CNAME must point to `<tunnel-id>.cfargotunnel.com` for routing to work
- Ingress rules in config.yaml control traffic routing AFTER it reaches the tunnel
- Multiple replicas provide HA; each connects independently to Cloudflare edge

**Current Tunnels**:
- texasdust.org → wordpress.texasdust:80 (WordPress nonprofit site)

See `src/apps/infrastructure/cloudflared/README.md` for detailed setup.

## Observability (Metrics + Logs)

The cluster has comprehensive observability with automatic discovery of new workloads.

### Monitoring Stack

**Grafana** (http://grafana.internal)
- Centralized visualization for metrics and logs
- Credentials: admin / (from 1Password `grafana-admin-credentials`)
- 20+ built-in Kubernetes dashboards
- 5Gi Longhorn storage for dashboard persistence

**Prometheus** (kube-prometheus-stack)
- 7-day metric retention (15GB limit)
- 20Gi Longhorn storage
- Automatic ServiceMonitor/PodMonitor discovery across all namespaces
- Additional scrape configs for Talos components (etcd, kubelet, scheduler, controller-manager)

**Alertmanager**
- 25+ default alert rules enabled
- No notification channels configured (alerts generated but not sent)
- Add Slack/email/Discord notifications via `alertmanager.config` in values

### What's Already Monitored

**Infrastructure:**
- Cilium CNI (agent, operator, Hubble metrics)
- Longhorn storage (volume health, capacity, replicas)
- Cloudflared tunnels (connection status)
- External-DNS (record sync operations)

**Talos System:**
- etcd (consensus, operations)
- kubelet (pod/container metrics)
- cadvisor (container resource usage)
- kube-controller-manager
- kube-scheduler

**Platform Services:**
- cert-manager (certificate expiration tracking)
- ArgoCD (sync status, application health)

**Applications:**
- texasdust MariaDB (database metrics via mysqld-exporter)
- texasdust Valkey (cache metrics via redis-exporter)

### Automatic Discovery for New Workloads

**Option 1: Pod Annotations (Simplest)**

Add these annotations to your Deployment/StatefulSet pod template:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  template:
    metadata:
      annotations:
        prometheus.io/scrape: "true"    # Required: Enable scraping
        prometheus.io/port: "8080"      # Required: Metrics port
        prometheus.io/path: "/metrics"  # Optional: Default is /metrics
    spec:
      containers:
        - name: app
          image: my-app:latest
          ports:
            - containerPort: 8080
              name: metrics
```

**That's it!** The cluster-wide PodMonitor (`src/apps/infrastructure/kube-prometheus-stack/podmonitor-auto-discovery.yaml`) will automatically scrape metrics within 30 seconds.

**Option 2: ServiceMonitor (For Services)**

Create a ServiceMonitor for your service:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: my-app
  namespace: my-namespace
spec:
  selector:
    matchLabels:
      app: my-app
  endpoints:
    - port: metrics
      interval: 30s
```

Prometheus automatically discovers all ServiceMonitors (`serviceMonitorSelectorNilUsesHelmValues: false`).

### Accessing Metrics

**Grafana UI:**
```bash
# Access via HTTPRoute
open http://grafana.internal

# Or port-forward
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
open http://localhost:3000
```

**Query Metrics in Grafana:**
1. Go to Explore → Select "Prometheus" datasource
2. Query examples:
   ```promql
   # CPU usage per pod
   rate(container_cpu_usage_seconds_total[5m])

   # Memory usage
   container_memory_usage_bytes{namespace="texasdust"}

   # Database connections (MariaDB)
   mysql_global_status_threads_connected

   # Cache hit rate (Valkey)
   rate(redis_keyspace_hits_total[5m])
   ```

### Labels Applied Automatically

All metrics from auto-discovered pods get these labels:
- `namespace`: Kubernetes namespace
- `pod`: Pod name
- `container`: Container name
- `node`: Node name (urd, verdandi, or skuld)
- `app`: From `app.kubernetes.io/name` label
- `version`: From `app.kubernetes.io/version` label
- `component`: From `app.kubernetes.io/component` label

### Best Practices

1. **Always use Prometheus annotations** for new apps with metrics endpoints
2. **Check Grafana datasources** after adding new sources
3. **Store Grafana password in 1Password** (item: `grafana-admin-credentials` in kubernetes vault)
4. **Create dashboards in Grafana UI**, they persist to Longhorn storage
5. **Monitor certificate expiration** - cert-manager metrics now enabled

### Troubleshooting

**Metrics not appearing:**
```bash
# Check if PodMonitor discovered the pod
kubectl get podmonitors -A

# Check Prometheus targets
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Visit http://localhost:9090/targets

# Check pod annotations
kubectl get pod <pod-name> -n <namespace> -o yaml | grep -A5 annotations
```

**Dashboard not persisting:**
- Grafana uses Longhorn PVC for persistence
- Check: `kubectl get pvc -n monitoring`
- Dashboards are stored in `/var/lib/grafana`

### Documentation

See detailed documentation in:
- `src/apps/infrastructure/kube-prometheus-stack/README.md` - Prometheus/Grafana/Alertmanager
- `src/apps/infrastructure/longhorn/servicemonitor.yaml` - Storage metrics
- `src/apps/services/texasdust/README.md` - Application monitoring example

## Important Notes

- **Secure Boot**: This cluster uses Talos with Secure Boot enabled. Always use `-secureboot` images from Image Factory.
- **No Dedicated Workers**: Control planes run workloads (`allowSchedulingOnControlPlanes: true`)
- **High Pod Density**: Configured for 300 max pods per node (default is 110)
- **Storage**: iSCSI tools are installed for Longhorn distributed storage
- **GPU Support**: Intel i915 GPU drivers loaded via kernel module
- **Disk**: All nodes install to `/dev/nvme0n1` with disk wiping enabled

## Environment Variables

Key variables defined in `.mise.toml`:
```
URD_IP=192.168.0.120
VERDANDI_IP=192.168.0.121
SKULD_IP=192.168.0.122
CONTROL_PLANE_ENDPOINT=https://192.168.0.120:6443
```

Use these in mise tasks or export them for shell commands.
- wait wait, remember we are setting passwords always via 1Password connector, so if there are ever secret values prompt me to add them to the kubernetes vault so they can be synced first.
- no you never mention claude in prs
- Maybe you didn't wait long enough, it's a 3 minute polling period.