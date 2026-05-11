#!/usr/bin/env bash
set -euo pipefail

KUBECTL_CONTEXT="${KUBECTL_CONTEXT:-admin@norns}"
NAMESPACE="${NAMESPACE:-open-webui}"
STATEFULSET_NAME="${STATEFULSET_NAME:-open-webui}"
OPENWEBUI_VERSION="${OPENWEBUI_VERSION:-v0.9.5}"
TRACE_NAME="${TRACE_NAME:-open-webui-chat}"
GENERATION_NAME="${GENERATION_NAME:-open-webui-turn}"

usage() {
  cat <<'EOF'
Usage:
  scripts/configure-open-webui-langfuse.sh [options]

Options:
  --context <name>             kubectl context (default: admin@norns)
  --namespace <name>           namespace (default: open-webui)
  --statefulset <name>         StatefulSet name (default: open-webui)
  --open-webui-version <tag>   trace release suffix (default: v0.9.5)
  --trace-name <name>          Langfuse trace name (default: open-webui-chat)
  --generation-name <name>     Langfuse generation name (default: open-webui-turn)
  -h, --help                   show this help text
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --context)
      KUBECTL_CONTEXT="$2"
      shift 2
      ;;
    --namespace)
      NAMESPACE="$2"
      shift 2
      ;;
    --statefulset)
      STATEFULSET_NAME="$2"
      shift 2
      ;;
    --open-webui-version)
      OPENWEBUI_VERSION="$2"
      shift 2
      ;;
    --trace-name)
      TRACE_NAME="$2"
      shift 2
      ;;
    --generation-name)
      GENERATION_NAME="$2"
      shift 2
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

pod="$(
  kubectl --context "$KUBECTL_CONTEXT" get pods -n "$NAMESPACE" \
    -l app.kubernetes.io/name="$STATEFULSET_NAME" \
    -o jsonpath='{.items[0].metadata.name}'
)"

if [[ -z "$pod" ]]; then
  echo "No Open WebUI pod found in namespace '$NAMESPACE'" >&2
  exit 1
fi

echo "==> Updating persisted Open WebUI OpenAI connection config in pod $pod"

kubectl --context "$KUBECTL_CONTEXT" exec -n "$NAMESPACE" "$pod" -- \
  env TRACE_NAME="$TRACE_NAME" \
      GENERATION_NAME="$GENERATION_NAME" \
      OPENWEBUI_VERSION="$OPENWEBUI_VERSION" \
      python - <<'PY'
from open_webui.config import OPENAI_API_CONFIGS

trace_name = __import__("os").environ["TRACE_NAME"]
generation_name = __import__("os").environ["GENERATION_NAME"]
openwebui_version = __import__("os").environ["OPENWEBUI_VERSION"]

api_configs = dict(OPENAI_API_CONFIGS.value or {})
connection = dict(api_configs.get("0", {}) or {})
headers = dict(connection.get("headers", {}) or {})

headers.update(
    {
        "langfuse_trace_user_id": "{{USER_ID}}",
        "langfuse_session_id": "{{CHAT_ID}}",
        "langfuse_trace_name": trace_name,
        "langfuse_generation_name": generation_name,
        "langfuse_trace_release": f"open-webui-{openwebui_version.lstrip('v')}",
    }
)

connection["headers"] = headers
api_configs["0"] = connection

OPENAI_API_CONFIGS.value = api_configs
OPENAI_API_CONFIGS.save()
print("Saved Open WebUI Langfuse header config for connection 0")
PY

echo "==> Restarting $STATEFULSET_NAME to reload persisted config"
kubectl --context "$KUBECTL_CONTEXT" delete pod -n "$NAMESPACE" "$pod" --wait=false
kubectl --context "$KUBECTL_CONTEXT" rollout status -n "$NAMESPACE" "statefulset/$STATEFULSET_NAME"

echo "==> Verifying stored OpenAI connection config"
new_pod="$(
  kubectl --context "$KUBECTL_CONTEXT" get pods -n "$NAMESPACE" \
    -l app.kubernetes.io/name="$STATEFULSET_NAME" \
    -o jsonpath='{.items[0].metadata.name}'
)"

kubectl --context "$KUBECTL_CONTEXT" exec -n "$NAMESPACE" "$new_pod" -- \
  python - <<'PY'
from open_webui.config import OPENAI_API_CONFIGS
import json

print(json.dumps(OPENAI_API_CONFIGS.value.get("0", {}), indent=2))
PY
