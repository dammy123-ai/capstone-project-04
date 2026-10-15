# Zuri Market — Frontend

React + Vite storefront. Development uses Vite's dev server; production
builds to static files served by nginx.

## Environment variables

| Variable          | Used                                                      |
|--------------------|-------------------------------------------------------------|
| VITE_API_URL       | base URL for API calls — **baked in at build time**, not runtime |
| VITE_STORE_NAME    | fallback store name shown before the API responds              |

`VITE_API_URL` is left **empty** in the Docker/Kubernetes build, so the app
calls relative paths (`/api/products`) and lets nginx's reverse proxy (or the
Kubernetes Ingress) route them to the backend. Locally, set it explicitly to
the backend's real address (`http://localhost:5050`) since no proxy exists in
dev mode.

## Running locally

```bash
cp .env.example .env
npm install
npm run dev
```
Dev server runs on port 3000 in this environment (not Vite's 5173 default).

## Linting

```bash
npm run lint
```

## Docker

Multi-stage build: Node builds the static bundle, then an unprivileged nginx
image serves it.
```bash
docker build -t zuri-frontend:local --build-arg VITE_API_URL= .
```
The final stage runs `apk upgrade` (switching to `USER root` for that one
layer only, then back to the image's non-root `nginx` user) to pick up
security patches published after the base image itself — this is how a
real, organically-discovered Trivy finding (CVE in `libtiff`) was resolved.

## Why the API URL is a build argument, not an environment variable

Vite inlines `import.meta.env.VITE_*` values into the compiled JavaScript at
build time. A Kubernetes ConfigMap changed after the image is built has no
effect — the only way to change which API the frontend calls is to rebuild
the image with a different `--build-arg VITE_API_URL=...`.
