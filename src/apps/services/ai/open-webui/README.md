# Open WebUI

Open WebUI provides the user-facing chat interface for the cluster AI stack.

## What This Deployment Does

- Exposes Open WebUI at `http://open-webui.internal`
- Persists application data on a Longhorn PVC
- Uses a persistent `WEBUI_SECRET_KEY` from 1Password
- Connects to the in-cluster LiteLLM gateway at `http://litellm.litellm.svc.cluster.local:4000/v1`

## Required 1Password Items

Create these items in the `kubernetes` vault:

- `open-webui-secret`
  - `WEBUI_SECRET_KEY`
- `litellm-master-key`
  - `master-key`

## Important Note

Open WebUI stores many connection settings in its internal database after first
boot. In practice, that means the initial LiteLLM URL and API key should be
correct before the first successful startup.

## Access

- UI: `http://open-webui.internal`

On first launch, create the initial admin account in the UI.
