# Paperless-ngx

Document management system for scanning, indexing, and archiving all your paper documents.

## Features

- **Automatic OCR**: Extract text from scanned documents (100+ languages supported)
- **Full-text search**: Find documents by content, not just filename
- **Auto-tagging**: ML-powered document classification and tagging
- **Email import**: Consume documents sent to a dedicated email address
- **Consumption folder**: Auto-import from network share (perfect for ScanSnap)
- **Web UI**: Clean, modern interface accessible from anywhere
- **REST API**: Automate workflows and integrations

## Architecture

- **Application**: Paperless-ngx v2.14.7 (Python/Django)
- **Database**: PostgreSQL 16 (10GB storage)
- **Cache**: Redis 7 (1GB storage)
- **Storage**: Longhorn distributed storage
  - Data: 2GB (application data)
  - Media: 20GB (processed documents)
  - Export: 2GB (exported archives)
  - Consume: 10GB (incoming documents)

## Access

- **Internal**: https://docs.internal (via Gateway API HTTPRoute)
- **External**: (To be configured via Cloudflare Tunnel)

External-DNS automatically creates the `docs.internal` DNS record in UniFi.

## Prerequisites

Before deploying, you must create the following items in your 1Password kubernetes vault:

### 1. paperless-admin
Admin user credentials for initial login.
```
Fields:
  - username (text): Your desired admin username
  - password (password): Strong password for admin account
```

### 2. paperless-secret-key
Django secret key for cryptographic signing.
```
Fields:
  - secret-key (password): Random key (generate: openssl rand -base64 32)
```

### 3. paperless-postgresql
Database credentials.
```
Fields:
  - postgres-password (password): PostgreSQL admin password
  - password (password): PostgreSQL user password
```

### 4. paperless-redis
Redis authentication.
```
Fields:
  - redis-password (password): Redis password
```

### 5. paperless-email
Email import configuration (for receiving documents via email).
```
Fields:
  - host (text): IMAP server hostname (e.g., imap.gmail.com)
  - port (text): IMAP port (e.g., 993)
  - username (text): Email address
  - password (password): Email password or app-specific password
  - security (text): SSL or STARTTLS
  - from (text): Email address to consume from (usually same as username)
```

## Deployment

This app is managed by ArgoCD. Once you've created the 1Password items above:

```bash
# Commit and push the application manifest
git add src/apps/services/paperless-ngx/
git commit -m "feat: Add Paperless-ngx document management system"
git push

# ArgoCD will automatically deploy within ~3 minutes
# Or sync immediately via the ArgoCD UI/CLI
kubectl get applications -n argocd paperless-ngx
```

## ScanSnap iX 1600 Setup

### Option 1: Network Folder Scanning (Recommended)

The consumption folder is mounted at `/usr/src/paperless/consume` inside the pod and backed by Longhorn storage.

**Setup Steps:**

1. **Expose consumption folder via SMB/NFS**:

   You have two options:

   a) **Create a simple SMB/NFS server pod** that mounts the Paperless consume PVC

   b) **Use ScanSnap's built-in "Scan to Network Folder" feature** with a file server on your network

   For option (a), you can deploy a simple Samba server:

   ```yaml
   # Example SMB server deployment (add to k8s/ directory if needed)
   apiVersion: v1
   kind: Pod
   metadata:
     name: paperless-samba
     namespace: paperless-ngx
   spec:
     containers:
     - name: samba
       image: dperson/samba:latest
       volumeMounts:
       - name: consume
         mountPath: /paperless
       env:
       - name: SHARE
         value: "paperless;/paperless;yes;no;yes;all;none"
     volumes:
     - name: consume
       persistentVolumeClaim:
         claimName: paperless-ngx-consume
   ```

2. **Configure ScanSnap**:
   - Open ScanSnap Home software
   - Create a new profile: "Scan to Paperless"
   - Set destination to the network share (e.g., `\\192.168.0.x\paperless`)
   - Set file format to PDF (searchable PDF if you want ScanSnap's OCR as backup)
   - Paperless will re-OCR anyway, so regular PDF is fine too

3. **Scan**:
   - Press scanner button
   - Select "Scan to Paperless" profile
   - Documents automatically appear in Paperless within 60 seconds

### Option 2: Email Import

1. **Configure a dedicated email** (e.g., Gmail with app-specific password)
2. **Add credentials to 1Password** as `paperless-email` item (see Prerequisites)
3. **Email PDFs** to that address
4. **Paperless checks every 10 minutes** and imports new messages

### Option 3: Manual Upload

- Navigate to https://docs.internal
- Drag and drop files into the web UI
- Paperless processes them immediately

## Tips & Best Practices

### Document Organization

- **Tags**: Use tags for categories (receipts, bills, personal, tax, etc.)
- **Correspondents**: Set up common senders (utilities, banks, employers)
- **Document Types**: Define types (invoice, receipt, statement, contract)
- **Dates**: Paperless auto-detects dates from OCR text

### Scanning Workflow

1. **Batch scan everything** - Don't worry about sorting yet
2. **Let OCR run** - Full-text search works immediately
3. **Tag and organize** - Review and tag documents in batches
4. **Set up auto-matching rules** - Paperless learns from your tagging

### Performance

- **Initial import**: First-time OCR is slow. Be patient with large batches.
- **Consumption polling**: 60-second interval. Adjust via `PAPERLESS_CONSUMER_POLLING` if needed.
- **Task workers**: Currently set to 2 workers. Increase if you have lots of CPU.

## Maintenance

### Backup

Paperless exports are stored in the `export` volume. You can:
```bash
kubectl exec -n paperless-ngx deployment/paperless-ngx-main -- python manage.py document_exporter /usr/src/paperless/export
```

### Database Backup

PostgreSQL data is on Longhorn. Velero backs up PVCs automatically (if configured).

### Monitoring

Check consumption folder processing:
```bash
kubectl logs -n paperless-ngx -l app.kubernetes.io/name=paperless-ngx -f
```

## Troubleshooting

### Documents not appearing after scanning

1. Check consumption folder has files:
   ```bash
   kubectl exec -n paperless-ngx deployment/paperless-ngx-main -- ls -la /usr/src/paperless/consume
   ```

2. Check logs for errors:
   ```bash
   kubectl logs -n paperless-ngx -l app.kubernetes.io/name=paperless-ngx --tail=100
   ```

3. Verify permissions on SMB share

### Email import not working

1. Verify IMAP credentials in 1Password
2. Check polling interval (default: 10 minutes - wait at least one cycle)
3. Check logs:
   ```bash
   kubectl logs -n paperless-ngx -l app.kubernetes.io/name=paperless-ngx | grep -i mail
   ```

### OCR failing or inaccurate

- Paperless uses Tesseract OCR
- Language is set to `eng` (English). Add more via `PAPERLESS_OCR_LANGUAGES`
- Scanned documents should be at least 300 DPI for best results
- ScanSnap iX 1600 defaults to good settings, so this should be fine

## Resources

- [Paperless-ngx Documentation](https://docs.paperless-ngx.com/)
- [Configuration Options](https://docs.paperless-ngx.com/configuration/)
- [ScanSnap Support](https://www.fujitsu.com/us/products/computing/peripheral/scanners/scansnap/)
