# MCPProxy

This deploys [`smart-mcp-proxy/mcpproxy-go`](https://github.com/smart-mcp-proxy/mcpproxy-go) as a headless, internal-only MCP proxy on the cluster.

## What This Deployment Does

- Exposes MCPProxy at `http://mcp.internal/mcp` through the internal Gateway
- Runs with **no auth on `/mcp`** for LAN-only use
- Disables the web UI and management endpoints so configuration stays in Git
- Starts with an empty upstream server list; add upstreams by editing `manifests/configmap.yaml`

## Why It Is Set Up This Way

The upstream project is primarily designed as a desktop/LAN service. For this cluster deployment:

- `enable_tray` is disabled
- `features.enable_web_ui` is disabled
- `mcpproxy serve` runs with `--read-only` and `--disable-management`

That keeps the cluster version predictable and GitOps-friendly instead of treating the pod like an interactive desktop install.

## Current Runtime

- MCPProxy version: `v0.29.3`
- Runtime image: `ghcr.io/gaahrdner/mcpproxy:v0.29.3`
- Build source: [Dockerfile](/Users/gaahrdner/Code/homelab/src/apps/services/mcpproxy/Dockerfile)

This is now hermetic at runtime: the pod does not download MCPProxy on startup.

## Build And Publish

Build and push the image before ArgoCD syncs the deployment:

```bash
mise run mcpproxy-image-push
```

That publishes:

- `ghcr.io/gaahrdner/mcpproxy:v0.29.3`

If you want a different registry path, update:

- `MCPPROXY_IMAGE` in `.mise.toml`
- the image reference in `manifests/deployment.yaml`

If you keep the GHCR package public, the cluster does not need an image pull secret.

## Adding Upstream Servers

Edit `src/apps/services/mcpproxy/manifests/configmap.yaml` and add entries under `mcpServers`.

Example remote HTTP server:

```json
{
  "name": "context7",
  "url": "https://mcp.context7.com/mcp",
  "protocol": "http",
  "quarantined": false,
  "enabled": true
}
```

Set `quarantined: false` after you have reviewed and approved a server in Git. This cluster deployment keeps the management UI disabled, so Git is the approval path.

This cluster deployment is best suited to **remote HTTP MCP servers**. `mcpproxy` can also manage stdio servers, but that usually implies local binaries or Docker-based isolation, which is not what this setup is optimized for.

## Secrets

If an upstream MCP server needs credentials, put them in the 1Password `kubernetes` vault first and sync them into Kubernetes. Do not rely on MCPProxy's local keyring features in this containerized deployment.

## Hook It Up

### 1. Publish The Image

```bash
mise run mcpproxy-image-push
```

### 2. Let ArgoCD Sync

ArgoCD will pick up:

- [src/apps/services/mcpproxy/application.yaml](/Users/gaahrdner/Code/homelab/src/apps/services/mcpproxy/application.yaml)
- [src/apps/services/mcpproxy/manifests/deployment.yaml](/Users/gaahrdner/Code/homelab/src/apps/services/mcpproxy/manifests/deployment.yaml)

Check status with:

```bash
mise run mcpproxy-status
```

### 3. Add Upstream MCP Servers

Edit [src/apps/services/mcpproxy/manifests/configmap.yaml](/Users/gaahrdner/Code/homelab/src/apps/services/mcpproxy/manifests/configmap.yaml) and add remote HTTP servers under `mcpServers`, then commit and push.

Example:

```json
{
  "name": "context7",
  "url": "https://mcp.context7.com/mcp",
  "protocol": "http",
  "quarantined": false,
  "enabled": true
}
```

### 4. Point Clients At It

HTTP-native MCP clients:

- URL: `http://mcp.internal/mcp`

Codex CLI example:

```bash
codex mcp add mcpproxy --transport http http://mcp.internal/mcp
```

Claude Desktop still needs an HTTP-to-stdio bridge. Example:

```json
{
  "mcpServers": {
    "mcpproxy": {
      "command": "npx",
      "args": ["-y", "mcp-remote", "http://mcp.internal/mcp"]
    }
  }
}
```

## Client Notes

Clients that support HTTP MCP directly can connect to:

- `http://mcp.internal/mcp`

For Claude Desktop specifically, MCPProxy's docs still show a local bridge such as `mcp-remote` because Claude Desktop does not natively speak HTTP MCP.
