# Unla

This deploys [`AmoyLab/Unla`](https://github.com/AmoyLab/Unla) as the cluster's shared MCP gateway.

## What This Deployment Does

- Exposes the Unla web UI at `http://mcp.internal/`
- Exposes the shared MCP streamable HTTP endpoint at `http://mcp.internal:5235/mcp/user/mcp`
- Persists gateway configuration in SQLite on a Longhorn PVC
- Uses the official `ghcr.io/amoylab/unla/allinone:v0.9.0` image
- Keeps credentials in 1Password instead of Git

## Why This Replaces MCPProxy

`mcpproxy` worked as a desktop-style local proxy, but the cluster deployment hit real limits:

- OAuth flows were awkward inside a pod
- Docker-backed scanners and local runtime features were unavailable
- The best-fit use case here is a central, headless HTTP gateway for multiple clients

Unla is a better fit for that shape: it is explicitly designed as a gateway service with a management UI, streamable HTTP support, and Kubernetes deployment support.

## Required 1Password Item

Before first deploy, create this item in the 1Password `kubernetes` vault:

- Item: `unla-admin`
- Fields:
  - `username`
  - `password`
  - `jwt-secret-key`

Notes:

- `username` can simply be `admin`
- `password` should be strong
- `jwt-secret-key` should be a long random string, for example from `openssl rand -hex 32`

## Runtime

- Namespace: `unla`
- UI port: `80`
- MCP port: `5235`
- Config database: `/data/unla.db`

## Access

If UniFi DNS has propagated:

- UI: `http://mcp.internal/`
- MCP: `http://mcp.internal:5235/mcp/user/mcp`

If DNS is still missing, use the pinned service IP:

- UI: `http://192.168.0.206/`
- MCP: `http://192.168.0.206:5235/mcp/user/mcp`

## Hook It Up

### 1. Add The Admin Secret In 1Password

Create the `unla-admin` item in the `kubernetes` vault with the fields listed above.

### 2. Let ArgoCD Sync

ArgoCD will pick up:

- [src/apps/services/unla/application.yaml](/Users/gaahrdner/Code/homelab/src/apps/services/unla/application.yaml)
- [src/apps/services/unla/manifests/deployment.yaml](/Users/gaahrdner/Code/homelab/src/apps/services/unla/manifests/deployment.yaml)

Check status with:

```bash
mise run unla-status
```

### 3. Log In To The UI

Use the `username` and `password` from the `unla-admin` 1Password item.

### 4. Add Upstream MCP Servers

Use the Unla UI to add remote MCP servers or API-backed adapters.

Cluster-friendly upstreams should have:

- a stable HTTP URL reachable from Kubernetes
- static token or secret-URL auth where possible
- no dependence on localhost OAuth callbacks

### 5. Point Clients At It

HTTP-native MCP clients:

- URL: `http://mcp.internal:5235/mcp/user/mcp`

Codex CLI example:

```bash
codex mcp add unla --transport http http://mcp.internal:5235/mcp/user/mcp
```
