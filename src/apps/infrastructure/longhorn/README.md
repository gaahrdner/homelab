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
- **Backup Target**: Cloudflare R2 bucket `homelab-backup`, prefix `longhorn/`
- **Recurring Jobs**: daily volume backups and daily Longhorn system backups

## Dependencies

- iSCSI tools on Talos nodes (src/talos/extensions.yaml: siderolabs/iscsi-tools)
- Cilium L2 pool for LoadBalancer IP (infrastructure/cilium-l2)
- Gateway for HTTPRoute (infrastructure/gateway)

## UI Access

- Via LoadBalancer IP or https://longhorn.internal

## Required 1Password Fields

The existing `velero-r2-credentials` item is reused for Longhorn. It must include:

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_ENDPOINTS`

Use this value for `AWS_ENDPOINTS`:

- `https://48efe0f369d822f5035c1e179d993127.r2.cloudflarestorage.com`

## Backup Notes

- Longhorn handles retention for Longhorn backups. Do not put object lifecycle expiration rules on the `longhorn/` prefix in R2.
- The recurring job group `default` means volumes without explicit recurring-job labels still receive daily offsite backups.
