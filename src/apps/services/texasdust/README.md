# Ghost Blog for texasdust.org

This directory contains the Ghost blog platform configuration for the Texas Dust non-profit organization.

## Prerequisites

Before deploying Ghost, you must create the following items in your 1Password "kubernetes" vault:

### 1. ghost-credentials

Create a new item in 1Password with the following fields:

- **Type**: Password
- **Title**: `ghost-credentials`
- **Vault**: `kubernetes`
- **Fields**:
  - `ghost-password` (password field): The admin password for Ghost login

### 2. ghost-mysql-credentials

Create a new item in 1Password with the following fields:

- **Type**: Password
- **Title**: `ghost-mysql-credentials`
- **Vault**: `kubernetes`
- **Fields**:
  - `mysql-root-password` (password field): MySQL root user password
  - `mysql-password` (password field): MySQL ghost user password

## Deployment

Once the 1Password items are created:

1. Commit this directory to Git
2. Push to GitHub
3. ArgoCD will automatically sync and deploy Ghost

## Access

After deployment, Ghost will be available via LoadBalancer. To find the IP:

```bash
kubectl get svc -n ghost ghost -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

The Ghost admin interface will be at: `http://<LOADBALANCER_IP>/ghost`

Initial login credentials:
- Email: `admin@texasdust.org`
- Password: (from 1Password `ghost-credentials` item)

## Configuration

- **Blog Title**: Texas Dust
- **Namespace**: ghost
- **Storage**: 10Gi for Ghost content, 8Gi for MySQL
- **Resources**:
  - Ghost: 100m CPU / 256Mi memory (requests), 500m CPU / 512Mi memory (limits)
  - MySQL: 100m CPU / 256Mi memory (requests), 500m CPU / 512Mi memory (limits)

## Future Work

- Configure Cloudflare Access tunnel for public access
- Set up proper domain name (texasdust.org)
- Enable HTTPS
- Configure SMTP for email notifications
- Set up automated backups
