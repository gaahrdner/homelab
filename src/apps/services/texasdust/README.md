# texasdust.org - WordPress Nonprofit Site

WordPress-based website for Texas Dust nonprofit organization, deployed on Kubernetes with Valkey object caching and MariaDB database.

## Architecture

```
texasdust.org (public)
    ↓
Cloudflare Tunnel (af22f227-24f2-4520-8f39-90e0cc3403a9)
    ↓
wordpress.texasdust:80 (ClusterIP Service)
    ↓
WordPress Pods (2-10 replicas, HPA)
  ├─→ PHP-FPM (wordpress:6.8-php8.4-fpm)
  ├─→ Valkey object cache (valkey/valkey:8.1-alpine)
  └─→ MariaDB database (mariadb:11.4)
```

**Internal Access:** `texasdust.internal` (via HTTPRoute + external-dns)

## Components

### WordPress
- **Chart:** groundhog2k/wordpress v0.14.5
- **Image:** wordpress:6.8-php8.4-fpm
- **Replicas:** 2-10 (HPA based on 70% CPU utilization)
- **Storage:** 50Gi Longhorn PVC for uploads (ReadWriteOnce)
- **Security:** Non-root (www-data UID 33), restricted PSS, read-only root filesystem

### MariaDB
- **Image:** mariadb:11.4
- **Storage:** 20Gi Longhorn PVC (StatefulSet volumeClaimTemplate)
- **Features:** Thread pooling enabled (key advantage over MySQL)
- **Configuration:** Optimized for WordPress (query cache, InnoDB tuning)

### Valkey
- **Image:** valkey/valkey:8.1-alpine
- **Purpose:** Object caching (Redis protocol compatible)
- **Storage:** emptyDir (cache data doesn't need persistence)
- **Why Valkey:** Better performance (999.9K RPS), better licensing (BSD-3), 20% memory efficiency vs Redis

## Deployment

### Prerequisites

1. **Add MariaDB credentials to 1Password:**
   ```bash
   # In 1Password kubernetes vault, create item: wordpress-db-credentials
   # Required fields:
   #   - password: WordPress database user password
   #   - root-password: MariaDB root password
   ```

2. **Install WordPress Redis Object Cache plugin:**
   After initial deployment, install and activate the "Redis Object Cache" plugin in WordPress admin:
   - Dashboard → Plugins → Add New
   - Search "Redis Object Cache" (by Till Krüss)
   - Install and Activate
   - Dashboard → Settings → Redis → Enable Object Cache

### GitOps Deployment

ArgoCD automatically syncs from Git:

```bash
# After committing changes
git add .
git commit -m "feat: deploy WordPress for texasdust.org nonprofit site"
git push

# Check ArgoCD sync status
kubectl get application texasdust -n argocd

# Watch deployment
kubectl get pods -n texasdust -w
```

### Manual Deployment (if needed)

```bash
# Install dependencies
helm repo add groundhog2k https://groundhog2k.github.io/helm-charts/
helm repo update

# Deploy supporting infrastructure first
kubectl apply -f k8s/wordpress-secrets.yaml
kubectl apply -f k8s/mariadb-statefulset.yaml
kubectl apply -f k8s/valkey-deployment.yaml
kubectl apply -f k8s/networkpolicies.yaml

# Wait for database to be ready
kubectl wait --for=condition=ready pod -l app=mariadb -n texasdust --timeout=300s

# Deploy WordPress
helm upgrade --install wordpress groundhog2k/wordpress \
  --namespace texasdust \
  --create-namespace \
  --values k8s/wordpress-values.yaml

# Apply HTTPRoute
kubectl apply -f k8s/httproute.yaml
```

## Configuration

### WordPress Settings

**Database Configuration:**
- Host: `mariadb`
- Database: `wordpress`
- User: `wordpress`
- Password: From 1Password (wordpress-db-credentials)

**Object Cache (Valkey):**
- Host: `valkey`
- Port: `6379`
- Client: `phpredis`

**Site URL:** https://texasdust.org

### MariaDB Optimizations

Key features enabled:
- **Thread pooling** (`thread_handling = pool-of-threads`) - Enterprise MySQL feature, free in MariaDB
- InnoDB buffer pool: 1GB
- Query cache: 128MB
- Max connections: 300
- Optimized for WordPress query patterns

### Security Hardening

**Pod Security:**
- Namespace enforces `restricted` Pod Security Standard
- All containers run as non-root (UID 33 for WordPress/PHP, 999 for MariaDB/Valkey)
- Read-only root filesystem where possible
- All capabilities dropped
- No privilege escalation

**Network Security:**
- NetworkPolicies isolate components:
  - WordPress → MariaDB, Valkey, DNS, HTTPS (for updates)
  - MariaDB ← WordPress only
  - Valkey ← WordPress only
  - Gateway → WordPress only

**Secrets Management:**
- All passwords stored in 1Password vault
- OnePasswordItem syncs to Kubernetes secrets
- No hardcoded credentials in manifests

## Monitoring

### Prometheus Metrics

All components expose metrics:
- **WordPress:** Port 9253 (PHP-FPM metrics)
- **MariaDB:** Port 9104 (MySQL exporter)
- **Valkey:** Port 9121 (Redis exporter)

### Health Checks

```bash
# Check pod health
kubectl get pods -n texasdust

# Check WordPress logs
kubectl logs -n texasdust -l app=wordpress -c wordpress

# Check MariaDB connection
kubectl exec -n texasdust mariadb-0 -- mysqladmin ping -h localhost

# Check Valkey connection
kubectl exec -n texasdust -l app=valkey -- valkey-cli ping

# Test internal access
curl -H "Host: texasdust.internal" http://$(kubectl get svc -n texasdust wordpress -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Test public access
curl https://texasdust.org
```

## Performance

### Autoscaling

HPA configuration:
- Min replicas: 2
- Max replicas: 10
- Target CPU: 70%
- Scale-up: Fast (100% increase every 15s)
- Scale-down: Slow (50% decrease after 5min stabilization)

### Caching Layers

1. **Cloudflare CDN** - Edge caching for static assets
2. **Valkey Object Cache** - Database query caching (via WordPress plugin)
3. **PHP OpCode Cache** - Built into PHP 8.4

### Resource Allocation

**WordPress Pod:**
- Requests: 250m CPU, 256Mi memory
- Limits: 500m CPU, 512Mi memory

**MariaDB:**
- Requests: 500m CPU, 1Gi memory
- Limits: 1000m CPU, 2Gi memory

**Valkey:**
- Requests: 100m CPU, 256Mi memory
- Limits: 200m CPU, 512Mi memory

## Troubleshooting

### WordPress not connecting to database

```bash
# Check MariaDB is running
kubectl get pods -n texasdust -l app=mariadb

# Check database credentials secret exists
kubectl get secret -n texasdust wordpress-db-credentials

# Check 1Password sync
kubectl get onepassworditem -n texasdust wordpress-db-credentials

# Test database connection from WordPress pod
kubectl exec -n texasdust -l app=wordpress -c wordpress -- \
  mysql -h mariadb -u wordpress -p wordpress
```

### Object cache not working

```bash
# Check Valkey is running
kubectl get pods -n texasdust -l app=valkey

# Test Valkey connection
kubectl exec -n texasdust -l app=valkey -- valkey-cli ping

# Check from WordPress pod
kubectl exec -n texasdust -l app=wordpress -c wordpress -- \
  nc -zv valkey 6379
```

### Site not accessible via texasdust.org

```bash
# Check Cloudflare Tunnel is running
kubectl get pods -n cloudflared

# Check tunnel routing config
kubectl get configmap -n cloudflared cloudflared-config -o yaml

# Check Cloudflare Tunnel logs
kubectl logs -n cloudflared -l app=cloudflared

# Verify internal routing works
curl -H "Host: texasdust.internal" http://wordpress.texasdust
```

### Pods stuck in Pending

```bash
# Check PVC status
kubectl get pvc -n texasdust

# Check Longhorn volumes
kubectl get volumes -n longhorn-system

# Check pod events
kubectl describe pod -n texasdust <pod-name>
```

## Useful Links

- **WordPress Admin:** https://texasdust.org/wp-admin
- **WordPress Codex:** https://codex.wordpress.org/
- **Redis Object Cache Plugin:** https://wordpress.org/plugins/redis-cache/
- **GiveWP (Donations):** https://givewp.com/
- **The Events Calendar:** https://theeventscalendar.com/

## File Structure

```
src/apps/services/texasdust/
├── README.md                     # This file
├── application.yaml              # ArgoCD Application (multi-source)
└── k8s/
    ├── wordpress-values.yaml     # Helm chart values
    ├── mariadb-statefulset.yaml  # Database StatefulSet
    ├── valkey-deployment.yaml    # Object cache
    ├── wordpress-secrets.yaml    # 1Password integration
    ├── networkpolicies.yaml      # Security policies
    └── httproute.yaml            # Internal routing
```
