# Drop backend: Cloudflare-native rewrite plan

Status: DRAFT for approval. No backend code has been written yet.
Branch: `feat/cloudflare-backend` (based on `chore/phase1-security-hygiene`).

## 1. Goal

Replace the legacy Laravel 11 backend (`backend-admin/`) with a Cloudflare-native
service, keeping the REST API contract the two Flutter apps already use so the
apps need little or no change.

## 2. Target architecture

| Concern | Legacy (Laravel) | Target |
|---|---|---|
| API runtime | PHP / Laravel 11 | Cloudflare Workers, TypeScript, Hono |
| Database | MySQL | Supabase Postgres (+ PostGIS) via Cloudflare Hyperdrive |
| Money / wallet | Eloquent, 7 transaction sites | Postgres transactions, row locks, append-only ledger |
| Geo (nearby drivers, zones) | `acos()` haversine in raw SQL | PostGIS `geography`, GiST index, `ST_DWithin` |
| Auth | Sanctum opaque bearer tokens | Same token format, hashed in Postgres (apps unchanged) |
| Realtime (ride state, chat) | Firebase Firestore, written by backend | Keep Firestore in v1 (Worker writes via Firestore REST, service-account JWT) |
| Push | OneSignal | OneSignal REST (same app IDs) |
| Files (documents, avatars) | spatie/medialibrary | R2 (S3-compatible) |
| Background jobs | Laravel queues (sync) | Cloudflare Queues |
| Scheduled commands (11) | Artisan commands | Cron Triggers + Queues |
| Admin dashboard | Blade + DataTables | React SPA served by the same Worker at `/admin` (static assets), same API |
| Email | SMTP | Resend (connector available) |
| PDF / Excel exports | dompdf, maatwebsite/excel | Generated client-side or in a queue worker |
| Secrets | `.env` | Wrangler secrets, never in the apps |

Why Firestore stays in v1: the apps read ride, chat and user documents from
Firestore directly (RIDE_COLLECTION, RIDE_CHAT, USER_COLLECTION, config).
Replacing it means changing both apps. A later optional phase can move live
tracking to Durable Objects + WebSockets.

## 3. What the legacy backend contains

- 83 controllers, 53 models, 97 migrations, about 94 API routes.
- Business logic is concentrated in `app/Helpers/helper.php` (4,069 lines),
  `RideRequestController` (726), `UserController` (668), `RideRequestTrait` (501),
  `PaymentTrait` (428).
- Ride statuses used by the apps: `new_ride_requested`, `accepted`,
  `bid_accepted`, `arriving`, `arrived`, `in_progress`, `canceled`, `completed`.
- 11 Artisan commands: driver matching (`AssignDriverToRide`, `FindNearbyDriver`,
  `FindDriverForRegularRide`, `ChangeRideDriver`), scheduled rides
  (`FindScheduledRides`, `CleanExpiredScheduledRides`), driver payouts
  (`GenerateDriverPayoutReports`, `SendDriverPayoutReportMail`), housekeeping
  (`OfflineInactiveDrivers`, `AnonymizeInactiveUsers`, `DatabaseBackup`).
  No schedule definition was found in the repo, so cadence must be confirmed.
- Payment gateways in code today: wallet, cash, Stripe only.

## 4. API groups to port (in this order)

1. **Foundation**: project scaffold, env bindings, DB access, auth middleware,
   error/response format, OpenAPI spec generated from the legacy routes.
2. **Auth and users**: register, driver-register, login, social-login,
   forget-password, update-profile, change-password, delete-user-account,
   user-list/detail, driver documents.
3. **Reference data**: service-list, appsetting, language tables, FAQ, cancel
   reasons, airports, zones, additional fees, coupons.
4. **Rides**: estimate-price-time, save-riderequest, update, respond, bidding,
   drop points, complete, ratings, SOS, near-by-driver, matching jobs.
5. **Wallet and payments**: ledger, wallet-detail, save-wallet, coin wallet,
   withdraw requests, payouts, and new gateways: Paystack, Flutterwave, Korapay,
   Pocketfi (virtual accounts). Webhooks with signature verification.
6. **Notifications and support**: OneSignal push, complaints, chat, customer
   support.
7. **Admin**: dashboard, roles/permissions, settings, exports (React SPA).

Each group ships behind contract tests that replay recorded requests from the
Flutter apps against both backends.

## 5. Data model approach

- Rebuild the 97 MySQL migrations as a clean Postgres schema in Supabase
  migrations (not a line-by-line port): proper enums for ride status and user
  type, `numeric(14,2)` for money, `timestamptz`, `geography(Point)` for
  locations, foreign keys, and indexes on hot paths (ride status, driver
  online/available, location).
- Wallet: append-only `wallet_ledger` entries inside a transaction with the
  balance row locked (`SELECT ... FOR UPDATE`); idempotency keys on every payment
  webhook so a retried callback can never credit twice.
- Row Level Security enabled on all tables. The Worker is the only client; the
  apps never talk to Supabase directly.

## 6. Security requirements (non-negotiable)

- No payment secret keys in the apps. Payment intents and verification happen in
  the Worker. Apps hold public keys only.
- Webhook signature checks for every gateway; replay protection.
- Rate limiting on auth and OTP endpoints; secrets only via Wrangler secrets.
- Supabase service-role key used only by the Worker, never shipped.

## 7. Cloudflare resources

Workers (API, cron, and the `/admin` static assets), Hyperdrive (to Supabase), R2
bucket, Queues, KV (settings cache, rate limits). Environments: `dev`, `staging`,
`prod`. Hosted on the default `*.workers.dev` domain for now; a custom domain
(for example `api.<yourdomain>`) can be attached later without code changes.

## 8. Risks

- Largest risk is behavioural drift in fare calculation, bidding and matching
  logic that lives in `helper.php` and the ride trait. Mitigation: port with
  golden-file tests built from legacy outputs.
- Hyperdrive does not support some Postgres session features (prepared
  statements at SQL level, advisory locks, LISTEN/NOTIFY). Design avoids them.
- Workers CPU limits: heavy reports (payout PDFs, Excel exports) run in queue
  consumers or client-side, not in request handlers.

## 9. Decisions (resolved 2026-11-02)

1. Admin dashboard: web-based, served at `/admin` from the same Worker.
2. Live data exists in the old MySQL database and must be migrated (see section 11).
3. Supabase: project `drop` created on the free plan in `eu-west-2` (London),
   organization Kryptonia Group. See free-plan caveats in section 12.
4. Domain: default `workers.dev` for now; custom domain later.
5. Realtime: keep Firestore in v1. The Worker writes Firestore documents through
   the Firestore REST API, authenticating with a service-account JWT signed using
   WebCrypto (RS256), which Workers support. A spike in Phase B proves this
   before anything depends on it.
6. Job timing: see section 10.

## 10. Job timing (proposal)

Research basis. Uber publishes that it batches nearby riders and drivers for "a
few seconds" before pairing them, instead of instantly matching the closest
driver, but it does not publish the exact window or offer timeout. Bolt's driver
help article says scheduled rides are accepted by drivers in advance, the driver
must be online by the set time or the ride is reassigned, the rider gets 5
minutes after the scheduled start before a no-show cancellation fee applies, and
the fee goes to the driver if the rider cancels less than one hour before pickup.
Everything below that is a number rather than a rule from those sources is an
engineering default for Drop, to be tuned with real data.

Real-time dispatch is event-driven (Queues), not cron:

| Step | Default |
|---|---|
| Batch window after a ride request | 3 s, then pair riders and drivers together |
| Search radius | start 2 km, widen to 4 km, then 6 km if nobody accepts |
| Offer timeout per driver | 15 s, then offer to the next-best driver |
| Max offer rounds before "no drivers found" | 3 rounds (about 45 s) |
| Driver location ping | 5 s on a trip, 10 s online and idle |

Cloudflare Cron Triggers (UTC; Lagos is UTC+1):

| Job (legacy command) | Schedule |
|---|---|
| Find scheduled rides due (`FindScheduledRides`) | every minute: start dispatch 15 min before pickup; reminders to driver at 60 and 15 min |
| Reassign if scheduled driver is not online (`ChangeRideDriver`) | every minute, checks rides within 10 min of pickup |
| Expire unaccepted scheduled rides (`CleanExpiredScheduledRides`) | every 5 min |
| Set stale drivers offline (`OfflineInactiveDrivers`) | every 5 min (no location ping for 10 min) |
| Driver payout reports (`GenerateDriverPayoutReports`) | weekly, Monday 01:00 UTC (02:00 Lagos) |
| Payout report emails (`SendDriverPayoutReportMail`) | Monday 01:30 UTC |
| Anonymize inactive users (`AnonymizeInactiveUsers`) | daily 02:00 UTC |
| Database backup (`DatabaseBackup`) | nightly pg_dump to R2 via a scheduled GitHub Action (Workers cannot run pg_dump) |

## 11. Live data migration (MySQL to Postgres)

1. Take a full MySQL dump of production (owner provides; stored outside git).
2. Write an idempotent import tool in TypeScript that maps legacy tables to the
   new Postgres schema (users, driver documents, wallets and history, rides,
   payments, settings, languages). Runs repeatably against staging.
3. Money reconciliation gate: per-user wallet balance and total payments must
   match the legacy totals exactly before cutover.
4. Passwords: legacy bcrypt hashes are imported as is and verified with bcrypt on
   login, so users do not have to reset passwords.
5. Files: legacy uploads copied into R2, with URLs rewritten.
6. Cutover: freeze writes on the old system, run a final delta import, switch the
   apps' base URL, keep the old system read-only for rollback.

## 12. Supabase free plan caveats (read before go-live)

As far as I know, the free plan pauses projects after about a week of
inactivity, has a small database size cap, and has no automatic daily backups or
point-in-time recovery. That is fine for building and testing, but not for live
wallet and payment data. Plan to move to a paid plan before importing real
production data, and keep the nightly pg_dump to R2 either way.
