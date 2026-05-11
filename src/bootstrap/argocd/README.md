# ArgoCD Bootstrap

GitOps control plane for the workloads in `src/apps/`.

## Installation

Applied via `mise run bootstrap-gitops`:
1. Creates argocd namespace
2. Installs ArgoCD via Helm with custom values
3. Deploys the root Application that manages `src/apps/`

## Configuration

- **Namespace**: argocd
- **Server UI**: LoadBalancer on 192.168.0.200 (HTTP/HTTPS)
- **Root App**: Monitors `src/apps/` on the repository default branch
- **Sync**: Automated with prune and self-heal enabled

## Dependencies

- Cilium L2 pool for LoadBalancer IP
- Git repository: https://github.com/gaahrdner/homelab.git

## Post-Install

After bootstrap, all persisted workloads in `src/apps/` are managed by ArgoCD. Changes pushed to Git are auto-synced.
