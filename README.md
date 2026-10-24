# notifier

An Android (Flutter) FCM multi-purpose notifier app, to allow various 
applications/scripts/jobs to send alerts to my phone.

## architecture

```
system ──POST /v1/notify (Bearer <system key>)──▶ Cloud Run Function (Python)
                                                    │ key hash → system name (Secret Manager)
                                                    │ store alert (Firestore, 90-day TTL)
                                                    │ FCM high-priority data message ──▶ phone
phone ──GET /v1/alerts[/id] (app key)────────────▶ same function
```

FCM only carries `id`, `system`, `level`, and `title`; the description is
fetched from the function over HTTPS when an alert is opened. The app draws
notifications itself (`AlertNotifier.kt`), one channel per level.

## layout

- `app/`: Flutter Android app (Android 17+). See `app/Taskfile.yml`.
- `function/`: Cloud Run Function (Python). See `function/Taskfile.yml`.
- `ci/scripts/`: deploy script shared by CI and `task function:deploy`.
- `scripts/`: terraform-output helpers behind `task keys` and `task app:config`.

## api

All requests use `Authorization: Bearer <key>`. Sender keys identify a
system; the app key is only valid for the app endpoints.

| Method | Path | Key | Purpose |
|---|---|---|---|
| POST | `/v1/notify` | system | `{"title", "level"?, "description"?}`. `level` is `info` (default), `warning`, or `error`. |
| GET | `/v1/alerts?limit=&before=` | app | Newest first, no descriptions; page with `next_before`. |
| GET | `/v1/alerts/<id>` | app | Full alert, including description. |
| POST | `/v1/alerts/<id>/read` | app | Mark read. |
| POST | `/v1/devices` | app | `{"token"}`: register the app's FCM token. |

```sh
curl -X POST "$NOTIFIER_URL/v1/notify" \
  -H "Authorization: Bearer $NOTIFIER_KEY" \
  -H "Content-Type: application/json" \
  -d '{"level": "error", "title": "Service foo has failed", "description": "..."}'
```

## testing

Uses [`task`](https://taskfile.dev/); each component's Taskfile is included
under its folder name. Run `task` for the full list. Common targets:
- `task app:config ENV=dev|prod`: pull `google-services.json` and the API
  config from terraform outputs (needed before building)
- `task app:build`: release APK into `app/dist/notifier.apk`
- `task app:test` / `task app:analyze`
- `task app:emulator:install`: build, boot the Android 17 emulator, install, launch
- `task function:test`: function unit tests
- `task function:run`: function on :8080 with an in-memory store and no FCM;
  keys are `local-homelab-key` / `local-backups-key` / `local-app-key`
- `task function:deploy ENV=dev|prod`
- `task keys PROJECT=csenneff-dev|csenneff-prod`: print the API keys

The Test Notifications screen (flask icon) posts one local notification per
level through the same native code a push will use.

## setup

### 1. infrastructure

Everything in GCP (Firebase project + Android app, FCM, Firestore with the
90-day TTL, the `notifier` service account, keys, alert policies) is the
`notifier` module in [humeman/terraform](https://github.com/humeman/terraform)
(`tf/modules/notifier`). There's no manual Firebase console setup: FCM sends
authorize with the function's service account, so there's no server key.

Systems are listed in `tf/projects/<env>/project.tf`:

```hcl
module "notifier" {
  ...
  systems = ["homelab", "backups"]
}
```

Merging to `main` applies dev; prod is the manual `Apply Prod` workflow.

### 2. deploy the function

CI does this (`.github/workflows`, same pattern as humeman/financials):

- every push to `main` runs the function and app tests, then deploys to dev
- `Deploy to Prod` is run by hand (Actions → Deploy to Prod → Run workflow)
- PRs run the tests only

Both deploy jobs use the `GCLOUD_SERVICE_ACCOUNT` secret (a service account
key JSON) from the repo's `dev`/`prod` environments. Locally, the same script
runs with your gcloud login:

```sh
task function:deploy ENV=dev
```

The function runs as the `notifier` service account at
`https://us-central1-csenneff-<env>.cloudfunctions.net/notifier`. It's public
(`--allow-unauthenticated`); the keys are the auth. The deploy fails if the
URL doesn't answer `401` to an unauthenticated request afterwards.

### 3. get the keys

```sh
task keys PROJECT=csenneff-prod
```

Prints the function URL, each system's sender key, and the app key, read
from terraform outputs (via `sa/csenneff-<env>.json` in the terraform repo
if present, else your gcloud login). These are the plaintext keys: the
`notifier-keys` secret in Secret Manager only holds their SHA-256 hashes
(`{"systems": {"<hash>": "<name>"}, "app": "<hash>"}`), so it can't be used
to send.

Give each system its key; it sends `Authorization: Bearer <key>`. Adding or
removing a system is a terraform change; the function picks up the new keys
secret within 5 minutes, no redeploy. To rotate one key, `terraform apply
-replace='module.notifier.random_password.system_key["homelab"]'`; bump
`key_generation` to rotate all of them.

### 4. build and install the app

```sh
task app:config ENV=dev     # google-services.json + config/notifier.json (both gitignored)
task app:build              # app/dist/notifier.apk
```

`app:config` reads terraform outputs using `sa/csenneff-<env>.json` from the
terraform repo if present, else your gcloud login. Sideload the APK (it's
signed with the debug key; Android 17+ only). On first launch it asks for
notification permission and registers its FCM token with the function.

### 5. custom domain via Cloudflare (optional)

Cloud Run routes on the `Host` header, so a plain proxied CNAME to the
function returns 404. Two ways around it:

**Cloudflare Worker (recommended).** Keeps the orange cloud (WAF, rate
limiting) and works on the free plan:

1. Workers & Pages → Create → Worker, named e.g. `notifier-proxy`, with:

   ```js
   // Forwards notifier.csenneff.dev/* to the Cloud Run function.
   const ORIGIN = "https://us-central1-csenneff-prod.cloudfunctions.net/notifier";

   export default {
     async fetch(request) {
       const url = new URL(request.url);
       return fetch(ORIGIN + url.pathname + url.search, request);
     },
   };
   ```

2. Worker → Settings → Domains & Routes → Add → Custom domain:
   `notifier.csenneff.dev`. Cloudflare creates the DNS record and certificate.
3. Check it: `curl -i https://notifier.csenneff.dev/v1/alerts` should return
   `401 {"error": "invalid or missing key"}` (the function answering).

Optionally add a WAF rate-limiting rule on `notifier.csenneff.dev/v1/*`.

**Cloud Run domain mapping (no Worker).** Still in Preview, but supported in
us-central1:

1. Verify `csenneff.dev` for your Google account (`gcloud domains verify
   csenneff.dev`; adds a TXT record in Cloudflare).
2. `gcloud beta run domain-mappings create --service=notifier
   --domain=notifier.csenneff.dev --region=us-central1 --project=csenneff-prod`
3. In Cloudflare, add `CNAME notifier → ghs.googlehosted.com` as **DNS only**
   (grey cloud) — Google has to see its own records to issue the certificate,
   which can take up to 24h.

Either way, senders can use `https://notifier.csenneff.dev/v1/notify`. The
app keeps talking to the function URL from terraform, which is fine; to point
it at the custom domain instead, edit `NOTIFIER_URL` in
`app/config/notifier.json` after `task app:config` and rebuild.

## terraform

[`tf/modules/notifier`](https://github.com/humeman/terraform/tree/main/tf/modules/notifier)
in humeman/terraform.
