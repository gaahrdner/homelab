# homelab

A GitOps-managed Kubernetes homelab cluster running on Talos Linux.

## Cluster Overview

- **Cluster Name**: norns
- **Nodes**:
  - `urd`: 192.168.0.120 (Control Plane)
  - `verdandi`: 192.168.0.121 (Control Plane)
  - `skuld`: 192.168.0.122 (Control Plane)
- **Control Plane Endpoint**: `https://192.168.0.120:6443`
- **Talos Version**: v1.11.5
- **Kubernetes Version**: v1.34.1

## Prerequisites

- [mise](https://mise.jdx.dev/) - Task runner and environment manager
- [talosctl](https://www.talos.dev/) - Talos Linux CLI
- [kubectl](https://kubernetes.io/docs/tasks/tools/) - Kubernetes CLI
- [helm](https://helm.sh/) - Kubernetes package manager

## Installation

### New Cluster Installation

1. If you want to add additional Talos extensions, now is the time to modify `src/talos/extensions.yaml`
2. Generate a custom Talos image schematic: `mise run generate-schematic`.
   a. If this is a new machine, you'll need to prep the hardware and burn the ISO image, which entails:
      i. Ensuring Secure Boot is enabled in the BIOS
      ii. Restoring the Factory Keys
      iii. Resetting the platform to Setup Mode.
      iv. Booting all nodes and wiping their disks
3. Generate a cluster configuration: `mise run gen-cluster`
4. Initialize the cluster (applies configs, bootstraps, sets up kubeconfig): `mise run init`
5. Verify the health: `mise run health`
6. Setup networking (Gateway API, Cilium CNI, Hubble): `mise run setup-networking`

### Existing Cluster Updates

1. If you changed extensions.yaml: `mise run generate-schematic` and update `src/talos/patches/images.yaml` with the new installer path.
2. Regenerate configs (preserves secrets!): `mise run update`
3. Apply to all nodes: `mise run apply`
4. Verify health: `mise run health`

### Configuration Patches (`src/talos/`)

- `extensions.yaml` - System extensions (input for Image Factory)
- `patches/scheduling.yaml` - Allow pod scheduling on control planes
- `patches/image.yaml` - Custom Talos image with system extensions
- `patches/kubelet.yaml` - Kubelet configuration (max pods: 300)
- `patches/network-urd.yaml` - Hostname for urd node
- `patches/network-verdandi.yaml` - Hostname for verdandi node
- `patches/network-skuld.yaml` - Hostname for skuld node
- `patches/cilium.yaml` - Disable default CNI and kube-proxy (applied during `mise run setup-networking`)

### System Extensions (`src/talos/extensions.yaml`)

Current extensions:

- `siderolabs/gvisor` - Container runtime sandbox
- `siderolabs/i915` - Intel GPU drivers
- `siderolabs/intel-ucode` - Intel microcode updates
- `siderolabs/iscsi-tools` - iSCSI initiator tools (for Longhorn)
- `siderolabs/util-linux-tools` - Additional Linux utilities
