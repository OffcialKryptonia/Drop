# DROP (unified app)

One app, two modes. Rider mode is the default; approved drivers switch to driver mode from the side menu.

- `lib/` rider code (package `drop`)
- `lib/driver/` driver module, embedded from the former driver app. It keeps its own globals (`appStore`, `language`, `navigatorKey`) and runs inside `DriverShell` (a nested MaterialApp). Call `initDriverModule()` before showing it.
- Backend: Cloudflare Workers API (`worker/`), `POST /mode` switches `active_mode`.

Status: slice 4 of the unified-app plan (code merge). Mode switching UI arrives in slice 5, driver sign-up in slice 6, driver shell in slice 7.
