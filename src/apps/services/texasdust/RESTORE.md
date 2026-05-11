# Texasdust Restore Runbook

This runbook covers the restore paths for `texasdust` using the three backup
layers currently in the cluster:

1. Velero for Kubernetes objects and workload metadata
2. Longhorn for off-cluster PVC backups
3. MariaDB logical dumps in R2 for fast database recovery

Use the lightest restore path that solves the problem. Do not reach for a full
cluster restore if the issue is just a bad WordPress database.

## What Each Layer Is For

- `Velero`: restore namespaces, workloads, services, secrets, Argo-managed
  objects, and other Kubernetes metadata
- `Longhorn`: restore the WordPress uploads PVC and MariaDB PVC when the volume
  data itself is lost or corrupted
- `MariaDB logical dump`: restore WordPress content fast when the database is
  damaged but the cluster and MariaDB pod are otherwise intact

Important:

- The scheduled Velero backups for this repo do **not** include PVC data.
- For `texasdust`, PVC recovery comes from Longhorn backups.
- The fastest application-level recovery path for content is usually the
  logical MariaDB dump.

## Backup Locations

- Velero backup objects: `velero` namespace, storage location `default`
- Longhorn backups: `s3://homelab-backup/longhorn/`
- Texasdust MariaDB dumps:
  `s3://homelab-backup/logical-dumps/texasdust/mariadb/`

## Before You Start

Make sure you have:

- cluster access with `kubectl --context admin@norns`
- ArgoCD and 1Password operator healthy
- the `velero-r2-credentials` secret present in `texasdust`
- a clear decision on whether the problem is:
  - object/config loss
  - PVC/data loss
  - database corruption only

## Scenario 1: Database Restore Only

Use this when:

- WordPress is up but the site content is broken
- MariaDB data is corrupted
- the MariaDB PVC still exists and the pod can run

### 1. Freeze writes

Scale WordPress down before importing a dump:

```bash
kubectl --context admin@norns scale deploy -n texasdust wordpress --replicas=0
kubectl --context admin@norns wait --for=delete pod -n texasdust -l app=wordpress --timeout=300s
```

### 2. Find the dump you want

List the newest dump objects in R2 from a one-off pod:

```bash
cat <<'EOF' | kubectl --context admin@norns apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: texasdust-r2-list
  namespace: texasdust
spec:
  restartPolicy: Never
  containers:
  - name: aws
    image: amazon/aws-cli:2.17.45
    command:
    - /bin/sh
    - -c
    - |
      set -eu
      aws s3 ls s3://homelab-backup/logical-dumps/texasdust/mariadb/ \
        --recursive \
        --endpoint-url "${AWS_ENDPOINTS}" | tail -n 10
    env:
    - name: AWS_ACCESS_KEY_ID
      valueFrom:
        secretKeyRef:
          name: velero-r2-credentials
          key: AWS_ACCESS_KEY_ID
    - name: AWS_SECRET_ACCESS_KEY
      valueFrom:
        secretKeyRef:
          name: velero-r2-credentials
          key: AWS_SECRET_ACCESS_KEY
    - name: AWS_ENDPOINTS
      valueFrom:
        secretKeyRef:
          name: velero-r2-credentials
          key: AWS_ENDPOINTS
    - name: AWS_DEFAULT_REGION
      value: auto
EOF

kubectl --context admin@norns wait --for=condition=Ready=false pod/texasdust-r2-list -n texasdust --timeout=120s || true
kubectl --context admin@norns logs -n texasdust texasdust-r2-list
kubectl --context admin@norns delete pod -n texasdust texasdust-r2-list --ignore-not-found
```

### 3. Import the selected dump

Replace `DUMP_KEY` with the object key you want to restore.

```bash
cat <<'EOF' | kubectl --context admin@norns apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: texasdust-db-restore
  namespace: texasdust
spec:
  template:
    metadata:
      labels:
        app: mariadb-backup
    spec:
      restartPolicy: Never
      volumes:
      - name: work
        emptyDir: {}
      initContainers:
      - name: fetch
        image: amazon/aws-cli:2.17.45
        command:
        - /bin/sh
        - -c
        - |
          set -eu
          aws s3 cp "s3://homelab-backup/DUMP_KEY" /work/wordpress.sql.gz \
            --endpoint-url "${AWS_ENDPOINTS}"
          test -s /work/wordpress.sql.gz
          gunzip /work/wordpress.sql.gz
          test -s /work/wordpress.sql
        env:
        - name: AWS_ACCESS_KEY_ID
          valueFrom:
            secretKeyRef:
              name: velero-r2-credentials
              key: AWS_ACCESS_KEY_ID
        - name: AWS_SECRET_ACCESS_KEY
          valueFrom:
            secretKeyRef:
              name: velero-r2-credentials
              key: AWS_SECRET_ACCESS_KEY
        - name: AWS_ENDPOINTS
          valueFrom:
            secretKeyRef:
              name: velero-r2-credentials
              key: AWS_ENDPOINTS
        - name: AWS_DEFAULT_REGION
          value: auto
        volumeMounts:
        - name: work
          mountPath: /work
      containers:
      - name: restore
        image: mariadb:12.2
        command:
        - /bin/sh
        - -c
        - |
          set -eu
          mariadb -hmariadb -uroot wordpress < /work/wordpress.sql
        env:
        - name: MYSQL_PWD
          valueFrom:
            secretKeyRef:
              name: wordpress-db-credentials
              key: root-password
        volumeMounts:
        - name: work
          mountPath: /work
EOF
```

Watch it:

```bash
kubectl --context admin@norns get job -n texasdust texasdust-db-restore -w
kubectl --context admin@norns logs -n texasdust job/texasdust-db-restore -c restore
```

### 4. Bring WordPress back

```bash
kubectl --context admin@norns delete job -n texasdust texasdust-db-restore --ignore-not-found
kubectl --context admin@norns scale deploy -n texasdust wordpress --replicas=2
kubectl --context admin@norns rollout status deploy/wordpress -n texasdust --timeout=300s
```

### 5. Verify

```bash
kubectl --context admin@norns get pods -n texasdust
curl -I https://texasdust.org
```

## Scenario 2: PVC Restore With Longhorn

Use this when:

- the MariaDB PVC or WordPress uploads PVC is missing or corrupted
- the workload objects still exist, but the backing volume data is bad

High-level sequence:

1. Scale WordPress down.
2. In the Longhorn UI or CRDs, restore the affected volume from the backup
   target under `longhorn/`.
3. Reattach the restored volume to the right workload.
4. Start MariaDB first, then WordPress.
5. If MariaDB volume recovery is incomplete, fall back to the logical dump path
   above.

Useful checks:

```bash
kubectl --context admin@norns get pvc -n texasdust
kubectl --context admin@norns get volumes.longhorn.io -n longhorn-system
kubectl --context admin@norns get recurringjobs.longhorn.io -n longhorn-system
```

## Scenario 3: Objects Lost, Data Still Exists

Use this when:

- namespace resources were deleted or damaged
- PVCs and Longhorn data are still intact

Preferred order:

1. Restore Git desired state first by ensuring ArgoCD is healthy.
2. If needed, restore Kubernetes objects from Velero.
3. Let ArgoCD converge the app back to the repo state.
4. Only restore database content separately if the live MariaDB data is also bad.

Useful checks:

```bash
kubectl --context admin@norns get applications.argoproj.io texasdust -n argocd
kubectl --context admin@norns get backups.velero.io -n velero
```

## Scenario 4: Cluster Loss

Use this when:

- the cluster is gone or unrecoverable

Recovery order:

1. Rebuild the base cluster with Talos.
2. Bootstrap ArgoCD and 1Password Connect.
3. Restore cluster objects from Velero if needed.
4. Restore Longhorn backup target access.
5. Restore Texasdust PVCs from Longhorn backups.
6. If the MariaDB volume is not usable, restore from the logical dump instead.
7. Verify `texasdust` through Argo, pod health, and the public site.

## Known Good Signals

These are the checks that should be green after a clean recovery:

```bash
kubectl --context admin@norns get application texasdust -n argocd
kubectl --context admin@norns get pods -n texasdust
kubectl --context admin@norns get svc,endpoints -n texasdust
curl -I https://texasdust.org
```

Expected app state:

- `texasdust` Argo app: `Synced`, `Healthy`
- `mariadb-0`: `Running`
- `wordpress` deployment rolled out
- public `https://texasdust.org` responds normally

## Notes

- The logical backup CronJob is intentionally allowed through the MariaDB
  `NetworkPolicy` with label `app=mariadb-backup`.
- The backup job now writes the SQL dump first, verifies it is non-empty, and
  only then compresses and uploads it. This prevents false-success uploads when
  the dump step fails.
- Ignore the known bad historical object
  `logical-dumps/texasdust/mariadb/2026/05/11/042620Z.sql.gz`; it was created
  before the dump-failure fix and is only 20 bytes.
