#!/usr/bin/env bash
set -euo pipefail

# Bootstrap the internal CA and JWT authority pool Secrets required by
# Agent Substrate (ate-system). Existing Secrets are preserved so reruns
# never rotate active cluster signing keys.

KUBECTL_CONTEXT="${KUBECTL_CONTEXT:-admin@norns}"
NAMESPACE="${NAMESPACE:-ate-system}"
SUBSTRATE_VERSION="${SUBSTRATE_VERSION:-v1.0.1}"

kubectl_cmd=(kubectl --context "$KUBECTL_CONTEXT")

find_kubectl_ate() {
  if command -v kubectl-ate >/dev/null 2>&1; then
    command -v kubectl-ate
    return
  fi

  local os arch tmpdir bin url sha_url expected actual
  os="$(uname -s | tr '[:upper:]' '[:lower:]')"
  arch="$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/;s/arm64/arm64/')"
  tmpdir="$(mktemp -d)"
  bin="${tmpdir}/kubectl-ate"
  url="https://github.com/agent-substrate/substrate/releases/download/${SUBSTRATE_VERSION}/kubectl-ate-${os}-${arch}"
  sha_url="${url}.sha256"

  curl -sSfL -o "$bin" "$url"
  expected="$(curl -sSfL "$sha_url" | awk '{print $1}')"
  actual="$(shasum -a 256 "$bin" | awk '{print $1}')"
  if [[ "$expected" != "$actual" ]]; then
    echo "SHA256 mismatch for kubectl-ate (${expected} != ${actual})" >&2
    rm -rf "$tmpdir"
    exit 1
  fi
  chmod +x "$bin"
  echo "$bin"
}

KUBECTL_ATE="$(find_kubectl_ate)"

make_ca() {
  local name="$1" keytype="$2"
  if "${kubectl_cmd[@]}" get secret -n "$NAMESPACE" "$name" >/dev/null 2>&1; then
    echo "skipped: ${NAMESPACE}/${name} (already exists)"
  else
    "$KUBECTL_ATE" --context "$KUBECTL_CONTEXT" admin make-ca-pool \
      --ca-id=1 --key-type="$keytype" --name="$name" --secret-namespace="$NAMESPACE"
  fi
}

"${kubectl_cmd[@]}" get ns "$NAMESPACE" >/dev/null 2>&1 || "${kubectl_cmd[@]}" create ns "$NAMESPACE"

make_ca service-dns-ca-pool ED25519
make_ca pod-identity-ca-pool ED25519
make_ca postgres-ca-pool ED25519
make_ca actor-id-ca-pool ECDSAP256
make_ca egress-mitm-ca-pool ECDSAP256

if "${kubectl_cmd[@]}" get secret -n "$NAMESPACE" actor-id-ca-certs >/dev/null 2>&1; then
  echo "skipped: ${NAMESPACE}/actor-id-ca-certs (already exists)"
else
  tmp_crt="$(mktemp)"
  "${kubectl_cmd[@]}" get secret -n "$NAMESPACE" actor-id-ca-pool -o jsonpath='{.data.tls\.crt}' | base64 -d > "$tmp_crt"
  "${kubectl_cmd[@]}" create secret generic actor-id-ca-certs -n "$NAMESPACE" --from-file="ca.crt=${tmp_crt}"
  rm -f "$tmp_crt"
fi

if "${kubectl_cmd[@]}" get secret -n "$NAMESPACE" actor-id-jwt-pool >/dev/null 2>&1; then
  echo "skipped: ${NAMESPACE}/actor-id-jwt-pool (already exists)"
else
  "$KUBECTL_ATE" --context "$KUBECTL_CONTEXT" admin make-jwt-pool \
    --alg=ES256 --name=actor-id-jwt-pool --secret-namespace="$NAMESPACE"
fi
