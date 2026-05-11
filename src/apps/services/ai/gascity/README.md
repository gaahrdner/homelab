# Gas City

This directory stages a future Gas City deployment for the homelab. It is not
live in ArgoCD yet.

## Why It Is Staged

- Upstream supports Kubernetes, but its deployment model assumes self-built
  images and a city-specific controller bootstrap flow.
- Publishing the base images is safe to automate now.
- Deploying the controller is not safe to automate blindly until we choose a
  concrete city layout, prebaked city image strategy, and any required secrets.

There is intentionally no `application.yaml` in this directory yet. That keeps
ArgoCD from deploying a half-configured stack on the next push.

## Images

The repo now includes a GitHub Actions workflow at
`.github/workflows/publish-gascity-images.yaml` that publishes these images to
GHCR under `ghcr.io/gaahrdner/` by default:

- `gascity-agent-base`
- `gascity-agent`
- `gascity-controller`
- `gascity-mcp-mail`

The workflow is manual on purpose. It builds from an upstream
`gastownhall/gascity` git ref and publishes immutable tags such as `v1.1.0`.

## Current Scope

The vendored `k8s/` manifests here cover the cluster-side primitives that are
not city-specific:

- namespace
- Dolt StatefulSet + Service
- mcp-mail Deployment + Service
- agent and controller RBAC
- event cleanup CronJob

What is still missing before a real deploy:

- a chosen city configuration
- a prebaked city agent image built from `gc build-image`
- a controller Deployment or equivalent GitOps-safe bootstrap
- any provider credentials, which should be added to the 1Password
  `kubernetes` vault before deployment manifests reference them

## Recommended Rollout

1. Run the GHCR publish workflow for the upstream ref we want to trial.
2. Confirm the images exist in GHCR and set them public if we want to avoid
   pull-secret plumbing.
3. Build one prebaked city image on top of `gascity-agent`.
4. Add `application.yaml` only after the city image and secrets are ready.
