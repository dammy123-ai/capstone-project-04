# Zuri Market — DevOps Capstone

A full e-commerce storefront (React frontend + Express backend) deployed on
self-managed Kubernetes (k3s) on AWS, provisioned entirely with Terraform,
built and shipped through a CI/CD pipeline, and monitored with Prometheus and
Grafana.

## Live architecture

Developer → PR → GitHub Actions (ci.yml)
lint → test → Sonar quality gate → Trivy scan → push to GHCR
|
merge to main triggers
v
GitHub Actions (cd.yml)
Terraform provisions/updates AWS infra (OIDC, no stored keys)
|
SSM Run Command (no SSH) on the node
v
scripts/deploy.sh: k8s manifests + Helm
|
Kubernetes (k3s, one EC2 node) ← Ingress → frontend + backend
|
Prometheus + Grafana scrape /metrics


## Repository structure

backend/ Express API (port 5050 in this environment)
frontend/ React + Vite SPA, served via nginx in production
terraform/ bootstrap/ (state bucket), modules/, environments/dev
k8s/ namespace, RBAC, Deployments, Services, Ingress, ServiceMonitor
monitoring/ Helm values for kube-prometheus-stack
scripts/ deploy.sh (idempotent full deploy), sync-secrets.sh
.github/workflows/ ci.yml (build/test/scan/push), cd.yml (provision + deploy)


## Running locally

```bash
cd backend && cp .env.example .env && npm install && npm start      # :5050
cd frontend && cp .env.example .env && npm install && npm run dev   # :3000
```
or the whole stack with Docker:
```bash
docker compose up --build
```

## Cloud deployment

Infrastructure is provisioned by Terraform (`terraform/environments/dev`) and
deployed onto by `scripts/deploy.sh`. In normal operation neither is run by
hand — merging to `main` triggers both automatically via `cd.yml`, authenticating
to AWS through OIDC federation (no long-lived keys stored in GitHub).

Access to the node is exclusively through AWS Systems Manager Session Manager —
there is no SSH key and no open port besides 80 (the storefront itself).
Prometheus and Grafana are reached the same way, via SSM port-forwarding.

## CI/CD

- **ci.yml** — on every push/PR: lint, test, npm audit, one consolidated
  SonarCloud scan (single project spans both apps, sequenced before image
  builds to avoid a report-processing race we hit and fixed), then build +
  Trivy-scan + push to GHCR for each app, image-pushes gated on `main` only.
- **cd.yml** — on push to `main` touching infra/deploy paths: `terraform apply`
  against the `dev` environment, then an SSM-delivered command that pulls
  `main` on the node and runs `scripts/deploy.sh dev`.

## Security decisions

- No SSH anywhere; all node access via SSM.
- Secrets (API key, Grafana admin password) live in AWS Secrets Manager, never
  in Git. The node's IAM role can only *read* them — writing requires a human
  with real AWS credentials, deliberately.
- Kubernetes RBAC: application pods carry no API token; a scoped `ci-deployer`
  role can patch Deployments but cannot read Secrets or delete Pods.
- Third-party GitHub Actions used for security scanning (Trivy, SonarQube) are
  pinned to a commit SHA, not a movable tag, after the real March 2026 Trivy
  Action supply-chain compromise.
- GitHub Actions authenticates to AWS via OIDC (no stored access keys), scoped
  to this repository and `main` branch only.

## Troubleshooting notes from building this

- This repo has GitHub's newer **immutable OIDC subject claims** enabled
  (repos created after mid-2026). The AWS trust policy's `sub` condition must
  match the exact numeric-ID format shown under
  **Settings → Actions → OIDC**, not the classic `repo:owner/name` pattern —
  cost real time to track down.
- k3s's `kubectl` falls back to its default kubeconfig automatically; Helm
  does not. `KUBECONFIG=/etc/rancher/k3s/k3s.yaml` must be set explicitly.
- `nginx-unprivileged`-based images can't run `apk upgrade` as their default
  user; switch to `USER root` for that one layer, then back.

## One thing I'd do differently

Add a staging gate (GitHub Environment with required reviewers) in front of
`terraform apply` in `cd.yml`. Right now infrastructure changes apply fully
unattended on every merge to `main` — acceptable for a solo capstone, not
something I'd ship for a team without a review step first.
