# 1Password Connect + Operator

Provides secret synchronization from 1Password vault to Kubernetes Secrets.

## Prerequisites

Before ArgoCD can sync this application, you must manually create the required secrets.

### Creating the Secrets

The secret YAML files are located in the `secrets/` directory (gitignored).

**CRITICAL: The credentials secret requires special handling:**

1. **onepassword-credentials.yaml** - Standard Kubernetes Secret (`onepassword-connect-credentials`) containing raw `1password-credentials.json` (single base64-encoded in `data:`)

   Connect chart `v2.4+` mounts the secret key as a file at `/home/opuser/.op/1password-credentials.json` (`OP_SESSION=/home/opuser/.op/1password-credentials.json`) and parses raw JSON directly. Do **not** double base64-encode it.

   ```bash
   kubectl create secret generic onepassword-connect-credentials \
     --from-file=1password-credentials.json=./1password-credentials.json \
     --namespace onepassword --dry-run=client -o yaml > secrets/onepassword-credentials.yaml
   ```

2. **onepassword-token.yaml** - Operator access token (`onepassword-connect-token`)

   ```bash
   kubectl create secret generic onepassword-connect-token \
     --from-literal=token="YOUR_TOKEN" \
     --namespace onepassword --dry-run=client -o yaml > secrets/onepassword-token.yaml
   ```

See `secrets/secrets.example.yaml` for detailed setup instructions.

Apply the secrets:

```bash
kubectl apply -f secrets/onepassword-credentials.yaml
kubectl apply -f secrets/onepassword-token.yaml
```

**Note**: These are the only credentials that need to be manually applied. Everything else can be retrieved from 1Password.

## Verification

After ArgoCD syncs, verify the deployment:

```bash
# Check pods are running
kubectl get pods -n onepassword

# Check the operator can access Connect
kubectl logs -n onepassword -l app.kubernetes.io/name=onepassword-connect-operator
```

## Monitoring

Prometheus scrapes the Connect API metrics endpoint via the ServiceMonitor in
`k8s/servicemonitor.yaml`. The internal route is also owned by this app in
`k8s/httproute.yaml`.

- **1Password Connect API:** port `8080`, path `/metrics`

Verify it with:

```bash
kubectl get servicemonitor -n onepassword onepassword-connect
kubectl get svc -n onepassword onepassword-connect
```

## Usage

Create a OnePasswordItem resource to sync a secret from your vault:

```yaml
apiVersion: onepassword.com/v1
kind: OnePasswordItem
metadata:
  name: my-secret
  namespace: default
spec:
  itemPath: "vaults/kubernetes/items/my-secret"
```

This will create a Kubernetes Secret named `my-secret` with the contents from 1Password.
