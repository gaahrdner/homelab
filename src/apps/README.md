# Applications Directory

This directory contains all Kubernetes resources managed by ArgoCD.

## Structure

```
apps/
├── infrastructure/      # Cluster-level infrastructure
│   └── cilium-l2/      # LoadBalancer IP pool configuration
├── platform/           # Platform services (operators, controllers)
│   └── (1password, cert-manager, etc.)
└── services/           # Your applications
    └── (homepage, services, etc.)
```

## How It Works

ArgoCD watches this directory and automatically syncs all resources to the cluster.

- **Add a new app**: Create a directory with Kubernetes manifests, commit, push
- **Update an app**: Modify the manifests, commit, push
- **Delete an app**: Remove the directory, commit, push

## Application Types

### Infrastructure
Cluster-level configuration that other apps depend on:
- LoadBalancer IP pools
- Storage classes
- Network policies

### Platform
Services that provide capabilities to other apps:
- Secret management (1Password operator)
- Certificate management (cert-manager)
- Monitoring/logging

### Services
Your actual applications:
- Web services
- Databases
- Whatever you want to run

## Sync Policy

All apps use automated sync with:
- **prune: true** - Removes resources deleted from Git
- **selfHeal: true** - Reverts manual changes back to Git state
- **CreateNamespace: true** - Auto-creates namespaces

## Adding a New Application

1. Create directory: `apps/services/myapp/`
2. Add manifests: `deployment.yaml`, `service.yaml`, etc.
3. Commit and push
4. ArgoCD syncs automatically within ~3 minutes

Or force immediate sync via ArgoCD UI.
