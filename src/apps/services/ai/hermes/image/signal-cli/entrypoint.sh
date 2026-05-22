#!/usr/bin/env bash
set -euo pipefail

data_root="${XDG_DATA_HOME:-/var/lib/signal-cli}"
account_root="${data_root}/signal-cli/data"
printed_hint=0

mkdir -p "${account_root}"

has_account() {
  find "${account_root}" -mindepth 1 -maxdepth 1 -type d | grep -q .
}

while true; do
  if has_account; then
    echo "Linked Signal account detected, starting signal-cli daemon on 0.0.0.0:8080"
    if [ -n "${SIGNAL_ACCOUNT:-}" ]; then
      exec signal-cli -a "${SIGNAL_ACCOUNT}" daemon --http 0.0.0.0:8080
    fi
    exec signal-cli daemon --http 0.0.0.0:8080
  fi

  if [ "${printed_hint}" -eq 0 ]; then
    cat <<'EOF'
No linked Signal account found yet.

Link this pod as a secondary Signal device with:
  kubectl exec -it -n hermes deploy/signal-cli -- signal-cli link -n hermes-signal

Then, in Signal on your iPhone:
  Settings -> Linked devices -> Link new device

After you scan the QR code, this container will automatically start the daemon.
EOF
    printed_hint=1
  fi

  sleep 15
done
