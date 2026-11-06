# Payments design (Paystack, Flutterwave, Korapay, Pocketfi, wallet, cash)

## Principle
The apps hold **no gateway keys and no payment SDKs**. All provider secrets live in the Worker (Cloudflare secrets, entered in the dashboard). The old apps shipped secret keys (Stripe, Flutterwave) to every phone; that stops.

## Experience (native, no web pages)
Priority is a smooth, mobile-native flow. Users never land on a browser-style page.

1. **Wallet top-up by bank transfer (main path in Nigeria).** Each user gets a dedicated virtual account (Pocketfi; Paystack/Korapay can be added). The app shows the account number with a **Copy** button and bank name; the user pays from their banking app; the Worker receives the provider webhook and credits the wallet. The app updates live. No redirect, no card entry, no per-transaction fee beyond the provider's.
2. **Card, in-app.** The app asks the Worker to initialise the payment and receives an `access_code` (public, single-use). The provider's **Flutter SDK** (Paystack first) renders its payment sheet inside the app using only that code and the public key. The first successful card payment returns a reusable authorization, which the Worker stores (never the card number).
3. **Saved card, one tap.** Later payments use `POST /api/payments/charge-saved-card`; the Worker calls the provider's charge-authorization API. No screen at all. If the bank demands 2FA, the response asks the app to open the SDK sheet for that one payment.
4. **Ride payment.** Wallet, saved card and cash complete instantly in the app flow. Online card payment during a ride uses (2)/(3).

Honest limits: the first card payment may show the bank's own 3-D Secure / OTP step (inside the provider sheet). That is a bank rule, not something we can remove.

## Server rules for every path
- Secrets stay in the Worker. The app only ever receives public keys, `access_code`s and account numbers.
- **Crediting happens only on the server**, from a signature-verified webhook plus a server-side "verify transaction" call. The app's own "success" is never trusted; it just waits for the server to say `paid`.
- `GET /api/payment-gateway-list` returns enabled gateways with no keys.
- `GET /api/payments/{reference}` lets the app poll status.

## Provider findings (Nov 2026)
- **Korapay** has NGN virtual bank accounts (developers.korapay.com/docs/virtual-bank-accounts) and card payments via hosted checkout or direct API. No native payments SDK found (its mobile SDKs are for identity liveness). The direct card API would put raw card data through our server (PCI burden), so we avoid it.
- **Pocketfi**: no public API docs found by search; the account owner must supply the docs link or a dashboard screenshot before it is built.
- **Paystack**: official Flutter SDK (`paystack_flutter_sdk`, `access_code` flow) and charge-authorization for saved cards. Needs a Paystack business account (none yet).
- Update after reading the real docs: **Korapay NGN virtual accounts require the customer's BVN** and are capped at 50 accounts by default (support must raise it). **Pocketfi static accounts** (Kuda/Nomba/Paga) make BVN/NIN optional and document no cap; webhooks are HMAC-SHA512 of the raw body in header `Pocketfi-Signature`; sandbox base `https://api.pocketfi.ng/api/test`; live `https://api.pocketfi.ng/api/v1`; Bearer token auth.
- So the first build is **bank-transfer wallet top-up through Pocketfi virtual accounts** (fully native). Korapay follows for card/checkout where needed; in-app card SDK and saved cards need a Paystack (or similar) account.
- Pocketfi caveats to resolve in sandbox: the webhook masks the account number, email and phone, and carries `customer.id`; creation returns no customer id, so we map `customer.id` to our user by listing accounts (`GET /virtual-accounts/fetch` returns `user_id` and full account number) right after creation. The webhook has no explicit status field (treated as successful credit). No documented server-side transaction-verify endpoint was found; ask Pocketfi support.

## Providers
| Provider | Initialize | Webhook signature |
|---|---|---|
| Paystack | `POST /transaction/initialize` (returns `access_code`), `charge_authorization` for saved cards | HMAC-SHA512 of body, header `x-paystack-signature` |
| Flutterwave | `POST /v3/payments` | `verif-hash` header equals secret hash |
| Korapay | `POST /merchant/api/v1/charges/initialize` | HMAC-SHA256 of `data`, header `x-korapay-signature` |
| Pocketfi | dedicated virtual account per user | per Pocketfi docs; incoming transfer credits wallet |

Currency: NGN. Exact request fields are confirmed against each provider's current docs when that provider is implemented.

## Money rules
- Amounts stored as `numeric(14,2)`, never floats (legacy used `double`; import rounds to 2 dp and the migration reconciles totals).
- `wallet_ledger` is append-only with `balance_after`; a wallet credit/debit runs in one transaction with the wallet row locked.
- Idempotency: unique `(provider, provider_reference)` on intents, unique `idempotency_key` on ledger rows. A replayed webhook cannot credit twice.
- Amount and currency from the webhook must equal the intent's; mismatch = flagged, not credited.
- Rides: cash and wallet are settled by the Worker when the ride completes; online payment marks the ride paid via the same webhook path.

## Secrets (set in Cloudflare dashboard, never in chat or git)
`PAYSTACK_SECRET_KEY`, `FLUTTERWAVE_SECRET_KEY`, `FLUTTERWAVE_SECRET_HASH`, `KORAPAY_SECRET_KEY`, `POCKETFI_API_KEY`.

## App changes
Remove razorpay, stripe, paytabs, braintree, paypal, the old Paystack fork and the Flutterwave SDK. Add the official `paystack_flutter_sdk`. `PaymentScreen` becomes: wallet balance, Fund wallet (bank transfer details / card), saved cards, history.

## Build order
1. Migration: wallets, wallet_ledger, payment_gateways (no secrets), payment_intents, payments.
2. Wallet endpoints (balance, history).
3. Korapay virtual-account top-up (test mode) end to end; then Paystack card + saved cards; Pocketfi and Flutterwave afterwards.
4. App changes.

## Built: wallet and Pocketfi bank-transfer top-up (Nov 2026)
Endpoints (legacy names kept so the shipped apps keep working): `GET /api/wallet-detail`, `GET /api/wallet-list`, `GET /api/payment-gateway-list`; new: `GET /api/wallet/virtual-account`, `POST /api/webhooks/pocketfi`.
- **Account number**: created at Pocketfi on first request (static Kuda account), stored, reused. Needs the user's name, email and a Nigerian phone number.
- **Webhook URL to give Pocketfi** (Dashboard, Settings, Webhooks): `https://<your-domain>/api/webhooks/pocketfi`. Verified by HMAC-SHA512 of the raw body against the saved Secret key (test or live).
- **Idempotent**: one credit per `transaction.reference`, even for six simultaneous deliveries (tested).
- **Fee**: the wallet is credited the full amount the rider sent; Pocketfi's fee is recorded in `payment_events.fee` and is borne by DROP. Change in `routes/wallet.ts` if that policy changes.
- **Unknown customer or bad amount**: stored as `flagged` in `payment_events`, nothing credited, HTTP 200 (so Pocketfi does not retry). A reconcile screen in the admin comes later.
- **Customer id mapping**: learned from Pocketfi's accounts list right after creation and again on demand (`resolveCustomers`). That list grows with users; if it gets large, ask Pocketfi for a per-account lookup.
- Tests: `worker/test/wallet-smoke.mjs` (mock Pocketfi, 22 checks) and `worker/test/admin-smoke.sh`.
