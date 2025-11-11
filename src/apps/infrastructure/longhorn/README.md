# Longhorn Distributed Storage

Cloud-native distributed block storage for Kubernetes using iSCSI.

## Installation

Helm chart v1.10.0 managed by ArgoCD. UI exposed via LoadBalancer.

## Configuration

- **Default StorageClass**: Yes (3 replicas, ext4, Delete reclaim policy)
- **Storage Reserve**: 20% free space guaranteed per node
- **Replica Strategy**: Best-effort auto-balance, no soft anti-affinity
- **UI Service**: LoadBalancer (gets IP from cilium-l2 pool)
- **HTTPRoute**: longhorn.internal (via gateway/internal)

## Dependencies

- iSCSI tools on Talos nodes (src/talos/extensions.yaml: siderolabs/iscsi-tools)
- Cilium L2 pool for LoadBalancer IP (infrastructure/cilium-l2)
- Gateway for HTTPRoute (infrastructure/gateway)

## UI Access

- Via LoadBalancer IP or https://longhorn.internal
