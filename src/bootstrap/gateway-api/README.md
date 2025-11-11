# Gateway API CRDs

Kubernetes Gateway API v1.2.1 Custom Resource Definitions.

## Installation

Applied during `mise run setup-networking` before Cilium installation.

## Configuration

- **Version**: v1.2.1 (standard channel)
- **Source**: https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.1/standard-install.yaml

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
