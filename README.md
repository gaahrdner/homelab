# homelab

A GitOps-managed Kubernetes homelab cluster running on Talos Linux.

## Cluster Overview

- **Cluster Name**: norns
- **Nodes**:
  - `urd`: 192.168.0.120 (Control Plane)
  - `verdandi`: 192.168.0.121 (Control Plane)
  - `skuld`: 192.168.0.122 (Control Plane)
- **Control Plane Endpoint**: `https://192.168.0.120:6443`
- **Talos Version**: v1.12.5
- **Kubernetes Version**: v1.35.4

## Prerequisites

- [mise](https://mise.jdx.dev/) - Task runner and environment manager
- [talosctl](https://www.talos.dev/) - Talos Linux CLI
- [kubectl](https://kubernetes.io/docs/tasks/tools/) - Kubernetes CLI
- [helm](https://helm.sh/) - Kubernetes package manager

## Repo Maintenance

- Sync AI assistant instruction docs after editing `AGENTS.md`: `mise run sync-agent-docs`
- Create missing 1Password items for LiteLLM, Open WebUI, and Langfuse: `mise run generate-ai-1password-items`
- Reapply Open WebUI -> LiteLLM Langfuse trace header config after a reset: `mise run configure-open-webui-langfuse`

## Observability

- **Metrics and dashboards**: `kube-prometheus-stack` via ArgoCD
- **Grafana**: available at `http://grafana.internal`
- **ArgoCD**: available at `http://argocd.internal`
- **Logs**: Loki (`grafana-community/helm-charts`) with Alloy collection (`grafana/helm-charts`)
- **App metrics**: 1Password Connect, Texasdust WordPress/MariaDB/Valkey, Paperless PostgreSQL/Redis/SMB, and Keeper PostgreSQL/Redis are scraped automatically

## Backups

- **Velero**: cluster object and workload metadata backups to Cloudflare R2
- **Longhorn**: recurring off-cluster volume backups to the `longhorn/` prefix in the same R2 bucket
- **Logical DB dumps**: daily Texasdust MariaDB and Paperless PostgreSQL dumps to `logical-dumps/`

The backup layers are intentionally split:
- Velero for Kubernetes objects
- Longhorn for PVC data
- logical dumps for faster app-level database recovery

Service-specific restore docs:

- [Texasdust restore runbook](src/apps/services/texasdust/RESTORE.md)

## Remote Access

- **Tailscale**: deployed in-cluster via the Kubernetes operator
- **Subnet router**: the cluster advertises the Kubernetes Service CIDR `10.96.0.0/12` and Pod CIDR `10.244.0.0/16` to the tailnet
- **Secrets**: operator OAuth credentials come from the 1Password `kubernetes` vault item `tailscale-operator-oauth`

See `src/apps/infrastructure/tailscale/README.md` for setup and policy requirements.

## Installation

### New Cluster Installation

#### Hardware Preparation

1. If you want to add additional Talos extensions, modify `src/talos/extensions.yaml`
2. Generate a custom Talos image schematic: `mise run generate-schematic`
3. If this is a new machine, prep the hardware and burn the ISO image:
   - Ensure Secure Boot is enabled in the BIOS
   - Restore the Factory Keys
   - Reset the platform to Setup Mode
   - Boot all nodes and wipe their disks

#### Base Cluster Bootstrap (3 Commands)

1. **Generate cluster configuration**: `mise run gen-cluster`
2. **Initialize the cluster**: `mise run init` (applies configs, bootstraps etcd, sets up kubeconfig)
3. **Setup networking**: `mise run setup-networking` (Gateway API, Cilium CNI with Hubble, replaces Flannel)

That gives you a working Talos + Kubernetes base cluster.

#### Standard GitOps Bootstrap

This repo assumes workloads are managed through ArgoCD:

1. Verify `src/bootstrap/argocd/root-app.yaml` points at the correct GitHub repo
2. Run: `mise run bootstrap-gitops`

Once ArgoCD is installed, it automatically syncs all applications in `src/apps/` including:

- LoadBalancer IP pool configuration
- Any platform services you add
- Your applications

For one-off experiments you can still apply manifests manually, but the normal operating model for this repo is GitOps after bootstrap.

### Existing Cluster Updates

1. If you changed extensions.yaml: `mise run generate-schematic` and update `src/talos/patches/image.yaml` with the new installer path.
2. Regenerate configs for the existing Cilium-based cluster (preserves secrets!): `mise run update`
3. Apply to all nodes: `mise run apply`
4. Verify health: `mise run health`

### Cluster Upgrades

1. Upgrade Talos one minor version at a time: `TALOS_IMAGE=<image> mise run upgrade`
2. Upgrade Kubernetes after Talos is on a compatible version: `KUBERNETES_VERSION=1.35.4 mise run upgrade-k8s`
3. Verify health and confirm `kube-proxy` did not return: `mise run health`

### Configuration Patches (`src/talos/`)

- `extensions.yaml` - System extensions (input for Image Factory)
- `patches/scheduling.yaml` - Allow pod scheduling on control planes
- `patches/image.yaml` - Custom Talos image with system extensions
- `patches/kubelet.yaml` - Kubelet configuration (max pods: 300)
- `patches/network-urd.yaml` - Hostname for urd node
- `patches/network-verdandi.yaml` - Hostname for verdandi node
- `patches/network-skuld.yaml` - Hostname for skuld node
- `patches/cilium.yaml` - Disable default CNI and kube-proxy (applied during `mise run setup-networking` and preserved by `mise run update`)

### Workload Tiers

- `src/apps/crds/`: cluster-scoped schema and migration-sensitive primitives
- `src/apps/infrastructure/`: core cluster platform services and shared singleton resources
- `src/apps/services/`: user-facing or platform-adjacent workloads
- `src/apps/services/ai/`: internal and experimental AI workloads built around LiteLLM, Open WebUI, and Langfuse

Current service workloads include:

- `texasdust`: WordPress site exposed through Cloudflare Tunnel
- `paperless-ngx`: internal document management
- `keeper`: internal calendar sync service at `http://keeper.internal`

### System Extensions (`src/talos/extensions.yaml`)

Current extensions:

- `siderolabs/gvisor` - Container runtime sandbox
- `siderolabs/i915` - Intel GPU drivers
- `siderolabs/intel-ucode` - Intel microcode updates
- `siderolabs/iscsi-tools` - iSCSI initiator tools (for Longhorn)
- `siderolabs/util-linux-tools` - Additional Linux utilities
