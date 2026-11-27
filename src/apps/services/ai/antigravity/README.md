# Antigravity Remote Dev Pod

Persistent Debian (`trixie-slim`) development environment running inside `norns` for both:

1. **Connect over SSH** from the desktop **Antigravity App** (`v2.33.0+`)
2. **Remote Control** from any desktop or phone browser (`https://antigravity.google.com`) via `agy --remote-control` inside `tmux`

## What's Installed

Built from [`image/Dockerfile`](image/Dockerfile) via [`.github/workflows/antigravity-dev-image.yaml`](../../../../../.github/workflows/antigravity-dev-image.yaml) (`ghcr.io/gaahrdner/antigravity-dev:main`):

- **Antigravity CLI (`agy`)** in `/usr/local/bin/agy` (owned by `dev`, so `agy update` works without `sudo`)
- **Go** (`1.27.4`), with `GOPATH=~/go` and `GOCACHE=~/.cache/go-build` on the PVC
- **Rust** (`stable` via `rustup`: `rustc`, `cargo`, `rustfmt`, `clippy`, `rust-analyzer`, `rust-src`), with `CARGO_HOME=~/.cargo` on the PVC
- **Python 3** (`python3`, `pip`, `venv`) + **`uv`** (`0.13.10`)
- **Tooling**: `mise`, `kubectl`, `helm`, `talosctl`, `gh`, `yq`, `jq`, `tmux`, `git`, `git-lfs`, `ripgrep`, `fd`, `fzf`, `build-essential`, `clang`, `lld`, `cmake`, `zsh`, `vim`
- **Storage**: 40Gi Longhorn PVC mounted at `/home/dev` (persists repos, build caches, `~/.gemini/`, `~/.antigravity-hub-server/`, and SSH host keys in `/home/dev/.ssh-host-keys/`)

## Option 1: Connect over SSH (Antigravity App)

1. Verify SSH connectivity from your workstation:
   - **On LAN:** `ssh dev@antigravity.internal`
   - **Away from home (via Tailscale subnet router `10.96.0.0/12`):** `ssh dev@<cluster-ip>` (check `kubectl get svc -n antigravity antigravity -o jsonpath='{.spec.clusterIP}'`)
2. In the **Antigravity App**, open the command palette (`Cmd+Shift+P`) → **Connect to SSH Host…** → enter `dev@antigravity.internal` (or a host alias from `~/.ssh/config`).
3. Complete Google OAuth in your local browser when prompted; credentials persist on the PVC under `~/.gemini/`.

## Option 2: Remote Control (Browser / Mobile)

Because Kubernetes containers do not run systemd user services (`agy remote-control start`), run `agy --remote-control` inside a persistent `tmux` session using the bundled helper:

```bash
ssh dev@antigravity.internal
agy-remote
```

- On first run, `agy` prints a Remote SSH OAuth URL — open it in your browser and paste the authorization code back into the terminal.
- Detach from `tmux` with `Ctrl-b d`; the agent and Remote Control tunnel stay active in the cluster.
- Open [https://antigravity.google.com](https://antigravity.google.com) on desktop or phone to control the session.
- Reattach later with `agy-remote` (or pass a custom session name and directory: `agy-remote homelab ~/workspace/homelab`).

## In-Cluster AI Endpoints

From inside the pod, internal AI services are directly reachable over cluster DNS:

- **LiteLLM (OpenAI-compatible):** `http://litellm.litellm.svc.cluster.local:4000/v1`
- **GX10 MCP (`laya_predict`, `generate_image`, `gx10_status`):** `http://gx10-mcp.litellm.svc.cluster.local:8080/mcp`
- **Arr MCP:** `http://arr-mcp.arr-mcp.svc.cluster.local:6060/mcp`
