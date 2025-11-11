# Gateway API - Internal Gateway

Shared HTTP gateway for internal `.internal` domain routing.

## Installation

Managed by ArgoCD via the root application. Manifests deployed from this directory.

## Configuration

- **Gateway Name**: `internal`
- **GatewayClass**: `cilium` (Cilium Gateway API implementation)
- **LoadBalancer IP**: 192.168.0.202
- **Listener**: HTTP on port 80
- **Route Namespaces**: All (HTTPRoutes can reference from any namespace)

## Dependencies

- Gateway API CRDs (bootstrap/gateway-api)
- Cilium CNI with Gateway API support (bootstrap/cilium)
- Cilium L2 LoadBalancer pool (infrastructure/cilium-l2)

## Usage

HTTPRoutes reference this gateway via:
```yaml
spec:
  parentRefs:
    - name: internal
      namespace: gateway
```
