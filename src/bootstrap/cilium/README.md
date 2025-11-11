# Cilium Bootstrap

eBPF-based CNI with kube-proxy replacement, Gateway API support, and L2 announcements.

## Installation

Installed via `mise run setup-networking`:
1. Applies Gateway API CRDs
2. Installs Cilium via Helm
3. Waits for Cilium to be ready
4. Applies Talos patch to disable default CNI/kube-proxy
5. Reboots nodes to complete transition

## Configuration

- **Version**: v1.18.3
- **kube-proxy replacement**: Enabled
- **Gateway API**: Enabled
- **L2 Announcements**: Enabled (LB2 mode)
- **Hubble**: UI and relay enabled for observability
- **IPAM**: Kubernetes host-scope

## Dependencies

- Gateway API CRDs (bootstrap/gateway-api)
- Talos nodes with cilium.yaml patch applied

## Components

- Cilium agent (eBPF networking)
- Cilium operator (resource management)
- Hubble relay and UI (network observability)
