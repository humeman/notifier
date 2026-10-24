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
- `function/`: Cloud Run Function (not yet written).

## testing

Uses [`task`](https://taskfile.dev/); each component's Taskfile is included
under its folder name. Run `task` for the full list. Common targets:
- `task app:build`: release APK into `app/dist/notifier.apk`
- `task app:test` / `task app:analyze`
- `task app:emulator:install`: build, boot the Android 17 emulator, install, launch

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
