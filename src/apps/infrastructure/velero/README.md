# Velero Backup Solution

This directory contains the ArgoCD Application manifests for deploying Velero, a Kubernetes backup and restore tool. Velero is configured to use Cloudflare R2 as its backup storage location and includes the CSI plugin for Longhorn volume snapshots.

## Components

*   `namespace.yaml`: Defines the `velero` namespace.
*   `onepassword-item.yaml`: Syncs R2 API credentials from 1Password into a Kubernetes Secret.
*   `application.yaml`: ArgoCD Application to deploy Velero via its Helm chart.

## Configuration Details

*   **Backup Storage:** Cloudflare R2 bucket (`homelab-backup`)
*   **R2 Endpoint:** `https://48efe0f369d822f5035c1e179d993127.r2.cloudflarestorage.com`
*   **Credentials:** Managed via 1Password Connect, referencing the `velero-r2-credentials` item in the `kubernetes` vault.
*   **Volume Snapshots:** Uses `velero-plugin-for-csi` to integrate with Longhorn for persistent volume snapshots. The `defaultVolumesnapshotClass` is set to `longhorn`.
*   **Velero Version:** Helm chart `2.31.0` (Velero application `v1.12.2`)
*   **Plugin Versions:** `velero-plugin-for-aws:v1.7.0`, `velero-plugin-for-csi:v1.7.0`

**Note on Versions:** The Velero and plugin versions used in `application.yaml` are based on common stable releases. It is recommended to verify these versions against the official Velero documentation for the latest compatible releases.

## Setup Instructions

1.  **Create R2 API Token:** Follow Cloudflare's documentation to create an R2 API token with "Object Read & Write" permissions.
2.  **Store Credentials in 1Password:** Create a new item named `velero-r2-credentials` in your 1Password "kubernetes" vault. Add the following fields: `bucket`, `account_id`, `access_key_id`, and `secret_access_key`.
3.  **Sync with ArgoCD:** Once these files are committed and pushed to your Git repository, ArgoCD will automatically deploy Velero to your cluster.

## Post-Installation

After Velero is deployed and running:

1.  **Verify Velero Pods:**
    ```bash
    kubectl get pods -n velero
    ```
2.  **Verify Backup Storage Location:**
    ```bash
    kubectl get bsl -n velero
    ```
3.  **Verify Volume Snapshot Location:**
    ```bash
    kubectl get vsl -n velero
    ```
4.  **Install Velero CLI (Optional):** For manual backups/restores and interaction, you can install the Velero CLI:
    ```bash
    brew install velero # On macOS
    ```
    Then configure it:
    ```bash
    velero client config set --kubeconfig ~/.kube/config
    ```
5.  **Create a Test Backup:**
    ```bash
    velero backup create my-first-backup --include-namespaces <your-namespace> --wait
    ```
