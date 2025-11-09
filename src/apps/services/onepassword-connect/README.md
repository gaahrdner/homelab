# 1Password Connect + Operator

Provides secret synchronization from 1Password vault to Kubernetes Secrets.

## Prerequisites

Before ArgoCD can sync this application, you must manually create the required secrets.

The secret YAML files are located in the `secrets/` directory (gitignored). Apply them:

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
