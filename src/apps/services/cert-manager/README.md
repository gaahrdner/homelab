# cert-manager

Automated TLS certificate management for Kubernetes using ACME (Let's Encrypt).

## Installation

Helm chart v1.19.1 managed by ArgoCD. The schema layer and ClusterIssuers live under `src/apps/crds/cert-manager/`, while this app owns the cert-manager controller deployment itself.

## Configuration

- **CRDs**: Installed separately from `src/apps/crds/cert-manager/crds.yaml`
- **Issuers**: staging and prod ClusterIssuers for Let's Encrypt
- **Components**: cert-manager, webhook, cainjector (1 replica each)

## Dependencies

- cert-manager CRDs and ClusterIssuers from `src/apps/crds/cert-manager/`

## Usage

Reference ClusterIssuers in Certificate or Ingress resources:
- `letsencrypt-staging` - for testing
- `letsencrypt-prod` - for production certificates
