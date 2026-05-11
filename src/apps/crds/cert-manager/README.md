# cert-manager CRD Layer

This directory holds the root-managed cert-manager schema layer.

## Contents

- `crds.yaml`: cert-manager CustomResourceDefinitions
- `cluster-issuer-prod.yaml`: production Let's Encrypt ClusterIssuer
- `cluster-issuer-staging.yaml`: staging Let's Encrypt ClusterIssuer

## Why It Lives Here

These resources are cluster-scoped and migration-sensitive under ArgoCD with `prune: true`. Keeping them in `src/apps/crds/` makes that ownership explicit instead of hiding them as a special case inside the cert-manager service directory.
