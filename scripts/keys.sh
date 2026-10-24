#!/usr/bin/env bash
# Prints the plaintext notifier keys for a project: one sender key per
# system (for POST /v1/notify) plus the app key. Secret Manager only holds
# their SHA-256 hashes, so terraform outputs are the one place these exist.
#
# Usage: keys.sh <project id, e.g. csenneff-prod> <path to humeman/terraform>
set -euo pipefail

PROJECT="${1:?Usage: keys.sh <project id> <terraform repo>}"
TF_REPO="${2:?Usage: keys.sh <project id> <terraform repo>}"

if [[ ! "${PROJECT}" =~ ^csenneff-([a-z0-9-]+)$ ]]; then
  echo "Expected a project ID like csenneff-prod, got '${PROJECT}'." >&2
  exit 1
fi
ENV="${BASH_REMATCH[1]}"

outputs="$("$(dirname "$0")/tf-output.sh" "${ENV}" "${TF_REPO}")"

python3 - "${outputs}" <<'PY'
import json, sys

out = json.loads(sys.argv[1])
try:
    url = out["notifier_function_url"]["value"]
    systems = out["notifier_system_keys"]["value"]
    app = out["notifier_app_key"]["value"]
except KeyError as e:
    sys.exit(f"terraform output {e} missing; has the notifier module been applied?")

width = max([len(name) for name in systems] + [len("(app)")])
print(f"URL: {url}\n")
print("Sender keys (Authorization: Bearer <key> on POST /v1/notify):")
for name in sorted(systems):
    print(f"  {name:<{width}}  {systems[name]}")
print(f"\nApp key (/v1/alerts, /v1/devices):\n  {'(app)':<{width}}  {app}")
PY
