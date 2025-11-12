# Cloudflared - Cloudflare Tunnel

Exposes internal Kubernetes services to the public internet via Cloudflare Tunnel.

## Overview

Cloudflared creates secure outbound-only connections to Cloudflare's edge network, allowing you to expose services without opening firewall ports. Traffic flows:

```
Internet → Cloudflare Edge → Tunnel → cloudflared pods → Kubernetes Service
```

**Architecture**: Locally-managed tunnel (configuration in Git, not dashboard-managed)

## Current Tunnels

### texasdust.org
- **Tunnel ID**: af22f227-24f2-4520-8f39-90e0cc3403a9
- **Backend**: `ghost.texasdust:80` (Ghost blog)
- **Replicas**: 2 (for high availability)

## Configuration

**Tunnel Credentials**: Stored in 1Password
- Vault: kubernetes (mbn7rk3d5gfgofrv3a2zt2tdoe)
- Item: cloudflare-tunnel-texasdust-org
- Key: token (contains credentials JSON)

**Ingress Rules**: Defined in ConfigMap
- Routes hostnames to internal Kubernetes services
- Uses service DNS names (e.g., `ghost.texasdust:80`)
- Catch-all returns 404 for unknown hosts

**DNS Routing**: Cloudflare DNS CNAME
- Record: `texasdust.org` → `af22f227-24f2-4520-8f39-90e0cc3403a9.cfargotunnel.com`
- Proxy: Enabled (orange cloud)

## Monitoring

- **Metrics Port**: 2000
- **ServiceMonitor**: Enabled for Prometheus scraping
- **Health Check**: `/ready` endpoint on port 2000

## Verification

Check tunnel status:
```bash
# Check pods
kubectl get pods -n cloudflared

# Check logs
kubectl logs -n cloudflared -l app=cloudflared

# Check Cloudflare dashboard
# Zero Trust → Networks → Tunnels
# Should show tunnel as "Healthy" with 2 connections
```

## Dependencies

- 1Password Connect (for credentials sync)
- Cloudflare DNS CNAME record pointing to tunnel
- Target service must exist and be accessible via cluster DNS

## Notes

- Cloudflared connects OUTBOUND to Cloudflare (no ingress needed)
- LoadBalancer/HTTPRoute on the service are independent and can coexist
- Multiple replicas provide HA but don't load balance (per Cloudflare design)
- Tunnel credentials are scoped to the specific tunnel
