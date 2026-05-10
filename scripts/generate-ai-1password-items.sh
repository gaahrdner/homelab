#!/usr/bin/env bash

set -euo pipefail

VAULT="${OP_VAULT:-kubernetes}"
OVERWRITE=0
TAGS="${OP_TAGS:-homelab,ai}"

usage() {
  cat <<'EOF'
Generate required 1Password items for LiteLLM, Open WebUI, and Langfuse.

Usage:
  scripts/generate-ai-1password-items.sh [--vault <name>] [--overwrite]

Options:
  --vault <name>   1Password vault name. Defaults to "kubernetes" or OP_VAULT.
  --overwrite      Replace generated values on existing items.
  -h, --help       Show this help text.

Notes:
  - This script intentionally does not create the optional LiteLLM provider-key item.
  - Existing items are skipped by default to avoid rotating live credentials by accident.
  - Use --overwrite only before deployment or when you are deliberately rotating secrets.
EOF
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command: $cmd" >&2
    exit 1
  fi
}

rand_hex() {
  local bytes="$1"
  openssl rand -hex "$bytes" | tr -d '\n'
}

rand_b64() {
  local bytes="$1"
  openssl rand -base64 "$bytes" | tr -d '\n'
}

item_exists() {
  local title="$1"
  op item get "$title" --vault "$VAULT" >/dev/null 2>&1
}

upsert_item() {
  local title="$1"
  shift
  local -a fields=("$@")

  if item_exists "$title"; then
    if (( OVERWRITE )); then
      op item edit "$title" --vault "$VAULT" "${fields[@]}" >/dev/null
      echo "updated: $title"
    else
      echo "skipped: $title (already exists)"
    fi
    return
  fi

  op item create \
    --vault "$VAULT" \
    --category login \
    --title "$title" \
    --tags "$TAGS" \
    "${fields[@]}" >/dev/null
  echo "created: $title"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --vault)
      VAULT="$2"
      shift 2
      ;;
    --overwrite)
      OVERWRITE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

require_cmd op
require_cmd openssl

if ! op vault get "$VAULT" >/dev/null 2>&1; then
  cat >&2 <<EOF
Unable to access 1Password vault "$VAULT".

Make sure:
  1. The 1Password CLI is signed in.
  2. Your current account can access the "$VAULT" vault.
  3. Desktop app integration or service-account auth is working.
EOF
  exit 1
fi

echo "Using 1Password vault: $VAULT"
if (( OVERWRITE )); then
  echo "Mode: overwrite existing items"
else
  echo "Mode: create missing items only"
fi

upsert_item \
  "litellm-master-key" \
  "master-key[password]=$(rand_hex 32)"

upsert_item \
  "litellm-postgresql" \
  "postgres-password[password]=$(rand_hex 24)" \
  "password[password]=$(rand_hex 24)"

upsert_item \
  "open-webui-secret" \
  "WEBUI_SECRET_KEY[password]=$(rand_b64 32)"

upsert_item \
  "langfuse-core-secrets" \
  "salt[password]=$(rand_b64 32)" \
  "nextauth-secret[password]=$(rand_b64 32)" \
  "encryption-key[password]=$(rand_hex 32)"

upsert_item \
  "langfuse-postgresql" \
  "postgres-password[password]=$(rand_hex 24)" \
  "password[password]=$(rand_hex 24)"

upsert_item \
  "langfuse-redis" \
  "password[password]=$(rand_hex 24)"

upsert_item \
  "langfuse-clickhouse" \
  "password[password]=$(rand_hex 24)"

upsert_item \
  "langfuse-minio" \
  "root-user[text]=langfuse" \
  "root-password[password]=$(rand_hex 24)"

echo "Done."
