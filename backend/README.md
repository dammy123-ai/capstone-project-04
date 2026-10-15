# Zuri Market — Backend

Express API serving the storefront's product and cart data.

## Endpoints

| Method | Path                  | Notes                                  |
|--------|-----------------------|-----------------------------------------|
| GET    | /api/health            | liveness/readiness probe target         |
| GET    | /api/store              | store name, product count               |
| GET    | /api/products            | list products                           |
| GET    | /api/products/:id          | single product                          |
| POST   | /api/cart/validate           | requires `x-api-key` header             |
| GET    | /metrics                       | Prometheus scrape target (not public)   |

## Environment variables

| Variable          | Required | Notes                                |
|--------------------|----------|----------------------------------------|
| PORT               | no       | defaults to 5050                       |
| API_SECRET_KEY     | yes      | checked against `x-api-key` header     |
| STORE_NAME         | no       | defaults to "My Store"                 |

In Kubernetes these come from a ConfigMap (`PORT`, `NODE_ENV`) and a Secret
(`API_SECRET_KEY`, `STORE_NAME`) synced from AWS Secrets Manager by
`scripts/sync-secrets.sh` — never committed, never in a manifest.

## Running locally

```bash
cp .env.example .env
npm install
npm start
```

## Testing and linting

```bash
npm run lint
npm test
```
The test suite is a single smoke test (`test/smoke.test.js`) that spawns the
server and hits `/api/health`.

## Docker

```bash
docker build -t zuri-backend:local .
docker run --rm -p 5050:5050 --env-file .env zuri-backend:local
```
The image strips the bundled npm/corepack/yarn CLI from the final layer after
`npm ci` — it was flagged by Trivy (10 HIGH CVEs, all inside npm's own
tooling, none in application dependencies) and isn't needed once the
container only runs `node server.js`.

## Metrics

`prom-client` exposes default Node.js metrics plus a custom
`http_request_duration_seconds` histogram, labeled by method/route/status.
Scraped by Prometheus via the `ServiceMonitor` in `k8s/backend/servicemonitor.yaml`.
