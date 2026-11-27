#!/usr/bin/env bash
set -euo pipefail

HOME_DIR="/home/dev"
HOST_KEYS_DIR="${HOME_DIR}/.ssh-host-keys"

# Ensure PVC root ownership for dev user on first boot
if [ "$(stat -c '%u:%g' "$HOME_DIR")" != "1000:1000" ]; then
  chown 1000:1000 "$HOME_DIR"
fi

# Create baseline directories on the PVC without overwriting user customizations
for dir in \
  "${HOME_DIR}/workspace" \
  "${HOME_DIR}/.ssh" \
  "${HOME_DIR}/.config" \
  "${HOME_DIR}/.cache" \
  "${HOME_DIR}/.cache/go-build" \
  "${HOME_DIR}/.cache/uv" \
  "${HOME_DIR}/.cargo" \
  "${HOME_DIR}/.local/bin" \
  "${HOME_DIR}/.gemini/antigravity-cli" \
  "${HOME_DIR}/go/bin"; do
  if [ ! -d "$dir" ]; then
    mkdir -p "$dir"
    chown 1000:1000 "$dir"
  fi
done
chmod 0700 "${HOME_DIR}/.ssh"
chown 1000:1000 "${HOME_DIR}/.ssh" "${HOME_DIR}/.local" "${HOME_DIR}/.gemini" "${HOME_DIR}/go" 2>/dev/null || true

if [ ! -f "${HOME_DIR}/.zshrc" ]; then
  cat <<'EOF' > "${HOME_DIR}/.zshrc"
setopt HIST_IGNORE_DUPS SHARE_HISTORY
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
PROMPT='%F{cyan}%n@%m%f:%F{yellow}%~%f%# '
if [ -z "${ANTIGRAVITY_RESOLVING_ENVIRONMENT:-}" ] && command -v mise >/dev/null 2>&1; then
  eval "$(mise activate zsh)"
fi
EOF
  chown 1000:1000 "${HOME_DIR}/.zshrc"
fi

if [ ! -f "${HOME_DIR}/.bashrc" ]; then
  cat <<'EOF' > "${HOME_DIR}/.bashrc"
PS1='\u@\h:\w\$ '
if [ -z "${ANTIGRAVITY_RESOLVING_ENVIRONMENT:-}" ] && command -v mise >/dev/null 2>&1; then
  eval "$(mise activate bash)"
fi
EOF
  chown 1000:1000 "${HOME_DIR}/.bashrc"
fi

if [ ! -f "${HOME_DIR}/.tmux.conf" ]; then
  cat <<'EOF' > "${HOME_DIR}/.tmux.conf"
set -g mouse on
set -g history-limit 50000
set -g default-terminal "tmux-256color"
set -ga terminal-overrides ",xterm-256color:Tc"
EOF
  chown 1000:1000 "${HOME_DIR}/.tmux.conf"
fi

# Persist SSH host keys on the PVC so reconnects survive pod restarts
mkdir -p "$HOST_KEYS_DIR"
chown root:root "$HOST_KEYS_DIR"
chmod 0700 "$HOST_KEYS_DIR"

if [ ! -f "${HOST_KEYS_DIR}/ssh_host_ed25519_key" ]; then
  ssh-keygen -t ed25519 -N "" -f "${HOST_KEYS_DIR}/ssh_host_ed25519_key"
fi
if [ ! -f "${HOST_KEYS_DIR}/ssh_host_rsa_key" ]; then
  ssh-keygen -t rsa -b 4096 -N "" -f "${HOST_KEYS_DIR}/ssh_host_rsa_key"
fi
chown root:root "${HOST_KEYS_DIR}"/ssh_host_*
chmod 0600 "${HOST_KEYS_DIR}"/ssh_host_*_key
chmod 0644 "${HOST_KEYS_DIR}"/ssh_host_*_key.pub

exec /usr/sbin/sshd -D -e
