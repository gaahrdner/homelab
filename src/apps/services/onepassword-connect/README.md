# 1Password Connect + Operator

Provides secret synchronization from 1Password vault to Kubernetes Secrets.

## Prerequisites

Before ArgoCD can sync this application, you must manually create the required secrets.

### Creating the Secrets

The secret YAML files are located in the `secrets/` directory (gitignored).

**CRITICAL: The credentials secret requires special handling:**

1. **onepassword-credentials.yaml** - Must be DOUBLE base64-encoded

   Why? The 1Password Connect server expects `OP_SESSION` to contain base64-encoded JSON, but Kubernetes automatically decodes secret values when injecting them as environment variables. To work around this, we double-encode so that after K8s decodes once, the value is still base64-encoded.

   ```bash
   # Generate the double-encoded value:
   cat 1password-credentials.json | base64 | tr -d '\n' | base64
   ```

2. **onepassword-token.yaml** - Use raw token value (NOT base64-encoded)

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
