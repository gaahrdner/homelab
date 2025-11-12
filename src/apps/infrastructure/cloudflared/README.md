# Cloudflared - Cloudflare Tunnel

Exposes internal Kubernetes services to the public internet via Cloudflare Tunnel.

## Overview

Cloudflared creates secure outbound-only connections to Cloudflare's edge network, allowing you to expose services without opening firewall ports. Traffic flows:

```
Internet → Cloudflare Edge → Tunnel → cloudflared pods → Kubernetes Service
```

## Current Tunnels

### texasdust.org
- **Tunnel ID**: c430d294-d821-4d3d-8eb9-11b6cd8ada5d
- **Backend**: `ghost.texasdust:80` (Ghost blog)
- **Replicas**: 2 (for high availability)

## Installation

Deployed as a standard Kubernetes Deployment managed by ArgoCD.

## Configuration

**Tunnel Token**: Stored in 1Password
- Vault: kubernetes (mbn7rk3d5gfgofrv3a2zt2tdoe)
- Item: cloudflare-tunnel-texasdust-org
- Key: token

**Ingress Rules**: Defined in ConfigMap
- Routes hostnames to internal Kubernetes services
- Uses service DNS names (e.g., `ghost.texasdust:80`)
- Catch-all returns 404 for unknown hosts

## Monitoring

- **Metrics Port**: 2000
- **ServiceMonitor**: Enabled for Prometheus scraping
- **Health Check**: `/ready` endpoint on port 2000

## Adding a New Public Service

1. **Create tunnel in Cloudflare Dashboard**:
   - Zero Trust → Networks → Tunnels → Create
   - Copy the tunnel token

2. **Store token in 1Password**:
   - Vault: kubernetes
   - Item: `cloudflare-tunnel-<domain>`
   - Key: `token`

3. **Create deployment** (copy this directory structure):
   - Update tunnel ID in ConfigMap
   - Update ingress rules
   - Update OnePasswordItem name
   - Update Deployment secret reference

4. **Commit and let ArgoCD sync**

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

- 1Password Connect (for token sync)
- Target service must exist and be accessible via cluster DNS

## Notes

- Cloudflared connects OUTBOUND to Cloudflare (no ingress needed)
- LoadBalancer/HTTPRoute on the service are independent and can coexist
- Multiple replicas provide HA but don't load balance (per Cloudflare design)
- Tunnel token is scoped to the specific tunnel
