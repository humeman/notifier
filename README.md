# notifier

An Android (Flutter) FCM multi-purpose notifier app, to allow various 
applications/scripts/jobs to send alerts to my phone.

## architecture

```
system ──POST /v1/notify (Bearer <system key>)──▶ Cloud Run Function (Python)
                                                    │ key hash → system name (Secret Manager)
                                                    │ store alert (Firestore, 90-day TTL)
                                                    │ FCM high-priority data message ──▶ phone
phone ──GET /v1/notifications[/id] (app key)─────▶ same function
```

FCM only carries `id`, `system`, `level`, and `title`; the description is
fetched from the function over HTTPS when an alert is opened. The app draws
notifications itself (`AlertNotifier.kt`), one channel per level.

## layout

- `app/`: Flutter Android app (Android 17+). See `app/Taskfile.yml`.
- `function/`: Cloud Run Function (Python). See `function/Taskfile.yml`.

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
- `task app:build`: release APK into `app/dist/notifier.apk`
- `task app:test` / `task app:analyze`
- `task app:emulator:install`: build, boot the Android 17 emulator, install, launch
- `task function:test`: function unit tests
- `task function:run`: function on :8080 with an in-memory store and no FCM;
  keys are `local-homelab-key` / `local-backups-key` / `local-app-key`
- `task function:deploy ENV=dev|prod`

The Test Notifications screen (flask icon) posts one local notification per
level through the same native code a push will use.

## setup

- Do something in FCM
- Get some JSON back
- ...
- ???
- Profit

## terraform

Link to the module in [humeman/terraform](https://github.com/humeman/terraform)
