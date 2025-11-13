# Applications Directory

This directory contains all Kubernetes resources managed by ArgoCD.

## Structure

```text
apps/
├── infrastructure/      # Cluster-level infrastructure
│   ├── cilium-l2/      # LoadBalancer IP pool configuration
│   └── longhorn/       # Distributed block storage
└── services/           # Everything else
    ├── cert-manager/   # TLS certificate management
    ├── onepassword-connect/  # 1Password secrets management
    ├── texasdust/      # WordPress nonprofit site for texasdust.org
    └── (your apps)     # Web services, databases, etc.
```

## How It Works

ArgoCD watches this directory and automatically syncs all resources to the cluster.

- **Add a new app**: Create a directory with Kubernetes manifests, commit, push
- **Update an app**: Modify the manifests, commit, push
- **Delete an app**: Remove the directory, commit, push

## Directory Guidelines

### Infrastructure

Cluster-level configuration that requires special handling:

- LoadBalancer IP pools (Cilium L2 announcements)
- Distributed storage (Longhorn)
- Storage classes
- Network policies

### Services

Everything else:

- Platform services (cert-manager, 1Password, monitoring)
- Your applications (websites, databases, etc.)

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
