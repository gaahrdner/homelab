# ArgoCD Bootstrap

GitOps continuous delivery tool that manages all applications in src/apps/.

## Installation

Applied via `mise run bootstrap-gitops`:
1. Creates argocd namespace
2. Installs ArgoCD via Helm with custom values
3. Deploys root Application that manages src/apps/

## Configuration

- **Namespace**: argocd
- **Server UI**: LoadBalancer on 192.168.0.200 (HTTP/HTTPS)
- **Root App**: Monitors src/apps/ for infrastructure and services
- **Sync**: Automated with prune and self-heal enabled

## Dependencies

- Cilium L2 pool for LoadBalancer IP
- Git repository: https://github.com/gaahrdner/homelab.git

## Post-Install

After bootstrap, all apps in src/apps/ are managed by ArgoCD. Changes pushed to Git are auto-synced.
