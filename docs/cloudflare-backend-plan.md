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
| Admin dashboard | Blade + DataTables | React SPA on Cloudflare Pages, same API |
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

Workers (API + cron), Hyperdrive (to Supabase), R2 bucket, Queues, KV (settings
cache, rate limits), Pages (admin SPA). Environments: `dev`, `staging`, `prod`.

## 8. Risks

- Largest risk is behavioural drift in fare calculation, bidding and matching
  logic that lives in `helper.php` and the ride trait. Mitigation: port with
  golden-file tests built from legacy outputs.
- Hyperdrive does not support some Postgres session features (prepared
  statements at SQL level, advisory locks, LISTEN/NOTIFY). Design avoids them.
- Workers CPU limits: heavy reports (payout PDFs, Excel exports) run in queue
  consumers or client-side, not in request handlers.

## 9. Decisions needed from the owner

1. Is there live data to migrate from the existing MySQL database, or is this a
   fresh launch? (Changes whether we write an import tool.)
2. Approve creating a new Supabase project (it may carry a cost; will confirm the
   cost with you before creating anything).
3. Cloudflare account: which account/zone and domain for the API
   (for example `api.<yourdomain>`)?
4. Confirm keeping Firestore for realtime in v1.
5. Cron cadence for matching, scheduled rides, payouts and inactivity cleanup.
