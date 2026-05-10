# Applications Directory

This directory contains all Kubernetes resources managed by ArgoCD.

## Structure

```text
apps/
├── infrastructure/           # Cluster-level infrastructure
│   ├── <app>/
│   │   ├── application.yaml  # ArgoCD Application watched by root app
│   │   ├── k8s/              # Child manifests / Helm values for that app
│   │   └── README.md
│   └── *.yaml                # Small shared resources synced directly by root
└── services/                 # Platform services and user workloads
    ├── <app>/
    │   ├── application.yaml
    │   ├── k8s/
    │   └── README.md
    └── <group>/<app>/        # Optional extra grouping for related services
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
- Shared network access tooling such as Tailscale subnet routing

### Services

Everything else:

- Platform services (cert-manager, 1Password, monitoring, logging)
- Your applications (websites, databases, etc.)
- Default for new workload access: prefer the cluster subnet router plus existing internal DNS and Gateway API entrypoints. Add Tailscale-published ingress only when a specific service benefits from tailnet-native discovery or ACLs.

## Sync Policy

All apps use automated sync with:

- **prune: true** - Removes resources deleted from Git
- **selfHeal: true** - Reverts manual changes back to Git state
- **CreateNamespace: true** - Auto-creates namespaces

## Adding a New Application

1. Create directory: `apps/services/myapp/`
2. Add `application.yaml`
3. Put Kubernetes manifests and Helm values under `k8s/`
4. Add `README.md` with prerequisites and operational notes
5. Commit and push
6. ArgoCD syncs automatically within ~3 minutes

Preferred layout:

```text
src/apps/services/myapp/
├── application.yaml
├── k8s/
│   ├── namespace.yaml
│   ├── onepassword-item.yaml
│   ├── deployment.yaml
│   └── service.yaml
└── README.md
```

Avoid introducing a separate `manifests/` directory. `k8s/` is the single payload
directory convention for child app resources.

Or force immediate sync via ArgoCD UI.
