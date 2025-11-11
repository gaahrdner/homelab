# cert-manager

Automated TLS certificate management for Kubernetes using ACME (Let's Encrypt).

## Installation

Helm chart v1.19.1 managed by ArgoCD. CRDs installed separately via crds.yaml.

## Configuration

- **CRDs**: Installed separately (not via Helm)
- **Issuers**: staging and prod ClusterIssuers for Let's Encrypt
- **Components**: cert-manager, webhook, cainjector (1 replica each)

## Dependencies

- cert-manager CRDs (cluster-issuer-*.yaml requires Certificate/Issuer CRDs)

## Usage

Reference ClusterIssuers in Certificate or Ingress resources:
- `letsencrypt-staging` - for testing
- `letsencrypt-prod` - for production certificates
