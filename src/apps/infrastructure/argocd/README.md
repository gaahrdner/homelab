# ArgoCD 1Password Integration

This directory contains 1Password-backed configuration for ArgoCD:

- `onepassword-item.yaml` for GitHub Container Registry credentials
- `admin-credentials-onepassword-item.yaml` for the ArgoCD admin login

## Setup

### 1. Create 1Password Items

For the ArgoCD admin login, create an item named `argocd-admin-credentials` in the `kubernetes` vault with these fields:

| Field Name  | Field Type | Value |
|------------|------------|-------|
| `username` | text | `admin` |
| `password` | password | `<your ArgoCD admin password>` |

For the GitHub Container Registry credentials, create an item named `github-ghcr-argocd-repo` in the same vault with these fields:

| Field Name  | Field Type | Value |
|------------|------------|-------|
| `type` | text | `helm` |
| `name` | text | `ghcr.io` |
| `url` | text | `ghcr.io` |
| `enableOCI` | text | `true` |
| `username` | text | `token` |
| `password` | password | `<your GitHub PAT with read:packages scope>` |

### 2. Apply Manifests

```bash
kubectl apply -f src/apps/infrastructure/argocd/onepassword-item.yaml
kubectl apply -f src/apps/infrastructure/argocd/admin-credentials-onepassword-item.yaml
```

### 3. Wait for Secret Sync

Wait ~3 minutes for the 1Password Connect operator to sync the secret:

```bash
kubectl wait --for=condition=Ready onepassworditem/ghcr-repository-credentials -n argocd --timeout=180s
```

### 4. Label the Secret

ArgoCD requires a specific label to recognize repository credentials:

```bash
kubectl label secret ghcr-repository-credentials \
  -n argocd \
  argocd.argoproj.io/secret-type=repository
```

### 5. Verify

Check that ArgoCD recognizes the repository:

```bash
kubectl get secret -n argocd ghcr-repository-credentials -o yaml | grep argocd.argoproj.io/secret-type
```

You should see: `argocd.argoproj.io/secret-type: repository`

## Usage

Once configured, ArgoCD can pull OCI Helm charts from ghcr.io without authentication errors. For example, the `paperless-ngx` application uses `oci://ghcr.io/gabe565/charts/paperless-ngx`.

## Troubleshooting

If you get 403 errors:

1. Verify the secret exists: `kubectl get secret ghcr-repository-credentials -n argocd`
2. Check the label: `kubectl get secret ghcr-repository-credentials -n argocd -o yaml | grep labels -A 5`
3. Verify the password field contains your GitHub PAT: `kubectl get secret ghcr-repository-credentials -n argocd -o jsonpath='{.data.password}' | base64 -d`
4. Restart ArgoCD to pick up changes: `kubectl rollout restart deployment argocd-repo-server -n argocd`
