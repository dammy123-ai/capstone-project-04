#!/usr/bin/env bash
set -euo pipefail
ENV_NAME="${1:?usage: sync-secrets.sh <dev|prod>}"
NS=zuri-market
TMP="$(mktemp)"
trap 'shred -u "$TMP" 2>/dev/null || rm -f "$TMP"' EXIT

aws secretsmanager get-secret-value --secret-id "zuri/${ENV_NAME}/backend" \
  --query SecretString --output text --region eu-west-1 \
  | jq -r 'to_entries[] | "\(.key)=\(.value)"' > "$TMP"

kubectl -n "$NS" create secret generic backend-secrets \
  --from-env-file="$TMP" --dry-run=client -o yaml | kubectl apply -f -