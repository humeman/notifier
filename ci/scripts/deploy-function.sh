#!/usr/bin/env bash
# Deploys the notifier Cloud Run function. Used by CI (.github/workflows) and
# `task function:deploy`.
#
# Usage: PROJECT_ID=csenneff-dev REGION=us-central1 ci/scripts/deploy-function.sh
set -euo pipefail

cd "$(dirname "$0")/../../function"

PROJECT_ID="${PROJECT_ID:?PROJECT_ID must be set}"
REGION="${REGION:-us-central1}"

FUNCTION_NAME="notifier"
RUNTIME="python313"
ENTRY_POINT="handle_request"
# Created by the terraform notifier module.
SERVICE_ACCOUNT="notifier@${PROJECT_ID}.iam.gserviceaccount.com"
KEYS_SECRET_NAME="notifier-keys"
RETENTION_DAYS="90"

# gcloud reads requirements.txt from --source.
cp requirements.txt src/requirements.txt
trap 'rm -f src/requirements.txt' EXIT

gcloud functions deploy "$FUNCTION_NAME" \
  --project="$PROJECT_ID" \
  --region="$REGION" \
  --gen2 \
  --runtime="$RUNTIME" \
  --source=src \
  --entry-point="$ENTRY_POINT" \
  --service-account="$SERVICE_ACCOUNT" \
  --set-env-vars="PROJECT_ID=${PROJECT_ID}" \
  --set-env-vars="KEYS_SECRET_NAME=${KEYS_SECRET_NAME}" \
  --set-env-vars="RETENTION_DAYS=${RETENTION_DAYS}" \
  --trigger-http \
  --allow-unauthenticated \
  --memory=256Mi \
  --max-instances=3 \
  --concurrency=1

URL=$(gcloud functions describe "$FUNCTION_NAME" \
  --project="$PROJECT_ID" \
  --region="$REGION" \
  --gen2 \
  --format="value(url)")
echo "URL: ${URL}"

# Smoke test: the function should be up and rejecting unauthenticated calls.
STATUS=$(curl -s -o /dev/null -w "%{http_code}" "${URL}/v1/alerts")
if [[ "$STATUS" != "401" ]]; then
  echo "Smoke test failed: GET /v1/alerts without a key returned ${STATUS}, expected 401." >&2
  exit 1
fi
echo "Smoke test passed (401 without a key)."
