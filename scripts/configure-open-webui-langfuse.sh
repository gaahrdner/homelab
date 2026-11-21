#!/usr/bin/env bash
set -euo pipefail

KUBECTL_CONTEXT="${KUBECTL_CONTEXT:-admin@norns}"
NAMESPACE="${NAMESPACE:-open-webui}"
STATEFULSET_NAME="${STATEFULSET_NAME:-open-webui}"
OPENWEBUI_VERSION="${OPENWEBUI_VERSION:-}"
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
  --open-webui-version <tag>   trace release suffix (default: pod image tag)
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

if [[ -z "$OPENWEBUI_VERSION" ]]; then
  image="$(
    kubectl --context "$KUBECTL_CONTEXT" get pod -n "$NAMESPACE" "$pod" \
      -o jsonpath='{.spec.containers[0].image}'
  )"
  if [[ "$image" == *:* ]]; then
    OPENWEBUI_VERSION="${image##*:}"
  else
    OPENWEBUI_VERSION="v0.13.4"
  fi
fi

echo "==> Updating persisted Open WebUI OpenAI connection config in pod $pod (release: open-webui-${OPENWEBUI_VERSION#v})"

kubectl --context "$KUBECTL_CONTEXT" exec -i -n "$NAMESPACE" -c open-webui "$pod" -- \
  env TRACE_NAME="$TRACE_NAME" \
      GENERATION_NAME="$GENERATION_NAME" \
      OPENWEBUI_VERSION="$OPENWEBUI_VERSION" \
      python - <<'PY'
import asyncio
import os
import open_webui.config  # noqa: F401 - initializes Config defaults and persistence
from open_webui.models.config import Config

trace_name = os.environ["TRACE_NAME"]
generation_name = os.environ["GENERATION_NAME"]
openwebui_version = os.environ["OPENWEBUI_VERSION"]


async def main() -> None:
    values = await Config.get_many("openai.api_configs")
    api_configs = dict(values.get("openai.api_configs") or {})
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

    await Config.upsert({"openai.api_configs": api_configs})
    print("Saved Open WebUI Langfuse header config for connection 0")


asyncio.run(main())
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

kubectl --context "$KUBECTL_CONTEXT" exec -i -n "$NAMESPACE" -c open-webui "$new_pod" -- \
  python - <<'PY'
import asyncio
import json
import open_webui.config  # noqa: F401
from open_webui.models.config import Config


async def main() -> None:
    values = await Config.get_many("openai.api_configs")
    api_configs = values.get("openai.api_configs") or {}
    print(json.dumps(api_configs.get("0", {}), indent=2))


asyncio.run(main())
PY
