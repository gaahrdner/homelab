# Gateway API CRDs

Kubernetes Gateway API v1.3.0 Custom Resource Definitions.

## Installation

Applied during `mise run setup-networking` before Cilium installation, and kept synced afterwards by the `gateway-api-crds` ArgoCD Application (`src/apps/infrastructure/gateway-api-crds/application.yaml`) with `prune: false` and `ServerSideApply=true`.

## Updating

When Renovate bumps `GATEWAY_API_VERSION` in `.mise.toml`, refresh `crds.yaml` into Git before merging:

```bash
mise run update-gateway-api-crds
```

## Configuration

- **Version**: v1.3.0 (standard channel)
- **Source**: https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.3.0/standard-install.yaml

## Dependencies

None - these are foundational CRDs.

## Provided CRDs

- Gateway
- GatewayClass
- HTTPRoute
- ReferenceGrant
- And other Gateway API resources

## Usage

Required by Cilium's Gateway API implementation and all HTTPRoute resources in the cluster.
