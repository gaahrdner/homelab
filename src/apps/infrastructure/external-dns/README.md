# External-DNS with UniFi Webhook

External-DNS automatically manages DNS records in your UniFi Dream Router for Kubernetes services and ingresses.

## Overview

This deployment uses:
- **external-dns** v1.15.0 - Watches Kubernetes resources and syncs DNS
- **UniFi webhook** v0.7.0 - Implements DNS provider for UniFi controllers

## Architecture

External-DNS runs with the UniFi webhook as a sidecar:
- External-DNS container watches Services, Ingresses, and HTTPRoutes
- UniFi webhook container handles DNS record management via UniFi API
- Communication happens over localhost:8888

## Configuration

**Managed Resources:**
- `Service` with type `LoadBalancer`
- `Ingress` resources
- Gateway API `HTTPRoute` resources

**Domain Filtering:**
- Only manages `.internal` domains
- Other domains are ignored

**UniFi Controller:**
- Host: `https://192.168.0.1`
- Site: `default`
- TLS verification: disabled (local setup)

## Secrets

The UniFi API key is stored in 1Password:
- Vault: `mbn7rk3d5gfgofrv3a2zt2tdoe`
- Item: `unifi-external-dns`
- Key: `api-key`

The OnePasswordItem resource syncs this to a Kubernetes secret in the `external-dns` namespace.

## DNS Record Management

External-DNS creates DNS records based on annotations:

**For LoadBalancer Services:**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-service
  annotations:
    external-dns.alpha.kubernetes.io/hostname: myapp.internal
spec:
  type: LoadBalancer
  # ...
```

**For HTTPRoutes:**
```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: my-route
spec:
  hostnames:
    - myapp.internal
  # ...
```

## TXT Registry

External-DNS uses TXT records to track ownership:
- Each DNS record gets a corresponding TXT record
- TXT records are prefixed with `external-dns-`
- Owner ID: `norns-cluster`

This prevents conflicts if multiple external-dns instances exist.

## Verification

Check external-dns logs:
```bash
kubectl logs -n external-dns deployment/external-dns -f
```

Check created DNS records:
```bash
# From a machine using the UniFi DNS
nslookup myapp.internal
```

## Troubleshooting

**DNS records not created:**
1. Check external-dns logs for errors
2. Verify UniFi API key is correct in 1Password
3. Ensure service has the correct annotation
4. Verify domain ends with `.internal`

**"Connection refused" errors:**
1. Check UniFi controller is reachable from cluster
2. Verify UNIFI_HOST is correct (192.168.0.1)

**TLS errors:**
1. Ensure UNIFI_SKIP_TLS_VERIFY is set to "true"
