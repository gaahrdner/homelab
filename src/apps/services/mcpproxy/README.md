# MCPProxy

This deploys [`smart-mcp-proxy/mcpproxy-go`](https://github.com/smart-mcp-proxy/mcpproxy-go) as an internal MCP proxy with the built-in web UI enabled.

## What This Deployment Does

- Exposes MCPProxy at `http://mcp.internal/mcp` through an internal LoadBalancer service
- Exposes the web UI at `http://mcp.internal/ui/`
- Leaves `/mcp` open on the LAN with `require_mcp_auth: false`
- Enables management through the web UI
- Seeds a default config from `manifests/configmap.yaml`, then persists runtime changes on a Longhorn PVC
- Uses a 1Password-sourced admin API key for web UI and REST API access

## Why It Is Set Up This Way

The upstream project is primarily designed as an interactive desktop/LAN service. This cluster deployment keeps that interaction model for administration:

- `enable_tray` is disabled
- `features.enable_web_ui` is enabled
- `mcpproxy serve` runs with management enabled
- the seed config is copied to `/data/config/mcp_config.json` on first boot and then owned by the application

That lets you manage upstream servers in the UI without losing changes on pod restarts.

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

If the package remains private, bootstrap the pull secret from the existing `argocd` GHCR credentials:

```bash
mise run mcpproxy-bootstrap-pull-secret
```

## Admin API Key

Before first deploy, create this item in the 1Password `kubernetes` vault:

- Item: `mcpproxy-admin-api-key`
- Field: `api-key` (password)

A hex key generated with `openssl rand -hex 32` is a good fit.

MCPProxy requires that admin API key for the web UI and REST API. `/mcp` remains unauthenticated unless you later turn on `require_mcp_auth`.

## Managing Upstream Servers

Use the web UI after the first deploy:

- UI: `http://mcp.internal/ui/?apikey=YOUR_KEY`
- MCP endpoint: `http://mcp.internal/mcp`

The ConfigMap is only a bootstrap seed now. After the first start, MCPProxy stores the live config on the PVC at `/data/config/mcp_config.json`, and UI changes persist there.

This deployment is best suited to **remote HTTP MCP servers**. `mcpproxy` can also manage stdio servers, but that usually implies local binaries or Docker-based isolation, which is not what this setup is optimized for.

## Secrets

If an upstream MCP server needs credentials, put them in the 1Password `kubernetes` vault first and sync them into Kubernetes. Do not rely on MCPProxy's local keyring features in this containerized deployment.

## Hook It Up

### 1. Publish The Image

```bash
mise run mcpproxy-image-push
```

If the GHCR package is private:

```bash
mise run mcpproxy-bootstrap-pull-secret
```

### 2. Add The Admin API Key In 1Password

Create `mcpproxy-admin-api-key` in the `kubernetes` vault with one password field named `api-key`.

### 3. Let ArgoCD Sync

ArgoCD will pick up:

- [src/apps/services/mcpproxy/application.yaml](/Users/gaahrdner/Code/homelab/src/apps/services/mcpproxy/application.yaml)
- [src/apps/services/mcpproxy/manifests/deployment.yaml](/Users/gaahrdner/Code/homelab/src/apps/services/mcpproxy/manifests/deployment.yaml)

Check status with:

```bash
mise run mcpproxy-status
```

Once the app syncs, open:

- `http://mcp.internal/ui/?apikey=YOUR_KEY`

If `mcp.internal` still has not propagated in UniFi DNS, use the service IP instead:

- `http://192.168.0.206/ui/?apikey=YOUR_KEY`

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
