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

**Current State**: Base Talos cluster infrastructure is configured. GitOps tooling (Flux/ArgoCD) is not yet set up.

**Key Details:**
- **Cluster Name**: norns
- **Talos Version**: v1.11.5
- **Kubernetes Version**: v1.34.1
- **Control Plane Nodes**: urd (192.168.0.120), verdandi (192.168.0.121), skuld (192.168.0.122)
- **Control Plane Endpoint**: https://192.168.0.120:6443
- **Task Runner**: mise (configured in `.mise.toml`)

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

**CRITICAL**: `secrets.yaml` contains cluster CA certificates and keys.

- This file is generated ONCE during initial cluster setup (`mise run gen-secrets`)
- It is preserved across config regenerations (`mise run update` reuses existing secrets)
- Regenerating this file will DESTROY the existing cluster
- The gen-secrets task will refuse to run if secrets.yaml already exists

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