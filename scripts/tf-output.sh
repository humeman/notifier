#!/usr/bin/env bash
# Prints `terraform output -json` for one environment of humeman/terraform.
#
# Runs terraform in Docker like that repo's Taskfile. Credentials:
# sa/csenneff-<env>.json in the terraform repo if present, otherwise your
# gcloud login (needs read access to the state bucket).
#
# Usage: tf-output.sh <dev|prod> <path to humeman/terraform>
set -euo pipefail

ENV="${1:?Usage: tf-output.sh <env> <terraform repo>}"
TF_REPO="$(cd "${2:?Usage: tf-output.sh <env> <terraform repo>}" && pwd)"
TF_VERSION="$(cat "${TF_REPO}/.terraform-version")"
SA="${TF_REPO}/sa/csenneff-${ENV}.json"

if [[ ! -d "${TF_REPO}/tf/projects/${ENV}" ]]; then
  echo "No terraform project for '${ENV}' in ${TF_REPO}/tf/projects." >&2
  exit 1
fi

auth=()
if [[ -f "${SA}" ]]; then
  auth=(-e "GOOGLE_APPLICATION_CREDENTIALS=/workspace/sa/csenneff-${ENV}.json")
else
  auth=(
    -e "GOOGLE_OAUTH_ACCESS_TOKEN=$(gcloud auth print-access-token)"
    -e "GOOGLE_BILLING_PROJECT=csenneff-${ENV}"
    -e "USER_PROJECT_OVERRIDE=true"
  )
fi

tf() {
  docker run --rm \
    -v "${TF_REPO}":/workspace \
    -v tf-plugin-cache:/root/.terraform.d/plugin-cache \
    -e TF_PLUGIN_CACHE_DIR=/root/.terraform.d/plugin-cache \
    "${auth[@]}" \
    -w "/workspace/tf/projects/${ENV}" \
    "hashicorp/terraform:${TF_VERSION}" "$@"
}

tf init -input=false >/dev/null
tf output -json
