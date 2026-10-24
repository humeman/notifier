#!/usr/bin/env bash
# Writes the environment-specific build inputs from the terraform notifier
# module's outputs:
#   android/app/google-services.json   (notifier_google_services_json)
#   config/notifier.json               (NOTIFIER_URL, NOTIFIER_APP_KEY)
#
# Terraform access goes through scripts/tf-output.sh (see there for
# credentials).
#
# Usage: config.sh <dev|prod> <path to humeman/terraform>
set -euo pipefail

ENV="${1:?Usage: config.sh <env> <terraform repo>}"
TF_REPO="${2:?Usage: config.sh <env> <terraform repo>}"

outputs="$("$(dirname "$0")/../../scripts/tf-output.sh" "${ENV}" "${TF_REPO}")"

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
