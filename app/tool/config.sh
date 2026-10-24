#!/usr/bin/env bash
# Writes the environment-specific build inputs from the terraform notifier
# module's outputs:
#   android/app/google-services.json   (notifier_google_services_json)
#   config/notifier.json               (NOTIFIER_URL, NOTIFIER_APP_KEY)
#
# Runs terraform in Docker like humeman/terraform's Taskfile. Credentials:
# sa/csenneff-<env>.json in the terraform repo if present, otherwise your
# gcloud login (needs read access to the state bucket).
#
# Usage: config.sh <dev|prod> <path to humeman/terraform>
set -euo pipefail

ENV="${1:?Usage: config.sh <env> <terraform repo>}"
TF_REPO="$(cd "${2:?Usage: config.sh <env> <terraform repo>}" && pwd)"
TF_VERSION="$(cat "${TF_REPO}/.terraform-version")"
SA="${TF_REPO}/sa/csenneff-${ENV}.json"

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
outputs="$(tf output -json)"

mkdir -p config
python3 - "${outputs}" <<'PY'
import json, sys

out = json.loads(sys.argv[1])
def value(name):
    if name not in out:
        sys.exit(f"terraform output {name} missing; has the notifier module been applied?")
    return out[name]["value"]

with open("android/app/google-services.json", "w") as f:
    f.write(value("notifier_google_services_json"))
with open("config/notifier.json", "w") as f:
    json.dump({
        "NOTIFIER_URL": value("notifier_function_url"),
        "NOTIFIER_APP_KEY": value("notifier_app_key"),
    }, f, indent=2)
    f.write("\n")
PY
chmod 600 config/notifier.json
echo "Wrote android/app/google-services.json and config/notifier.json (${ENV})."
