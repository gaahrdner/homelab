# CRD Tier

This directory holds cluster-scoped schema and other migration-sensitive primitives that are intentionally managed by the Argo root app.

## Why It Exists

- CRD ownership transfers are migrations, not cleanup.
- Keeping these resources in a dedicated tier makes the exception explicit instead of hiding it inside a service directory.
- Child applications can depend on these resources without also owning them.

## Current Contents

- `cert-manager/`: cert-manager CRDs and cluster-scoped issuers
