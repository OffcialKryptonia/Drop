# Payments design (Paystack, Flutterwave, Korapay, Pocketfi, wallet, cash)

## Principle
The apps hold **no gateway keys and no payment SDKs**. All provider secrets live in the Worker (Cloudflare secrets, entered in the dashboard). The old apps shipped secret keys (Stripe, Flutterwave) to every phone; that stops.

## Flow (card / bank / transfer)
1. `GET /api/payment-gateway-list` returns only enabled gateways: `id`, `title`, `type`, logo. Never keys.
2. `POST /api/payments/initiate` `{gateway, amount, purpose: wallet_topup | ride, ride_request_id?}`. The Worker creates a `payment_intents` row (status `pending`, unique `reference`), calls the provider's *initialize* API, and returns `{reference, checkout_url}`.
3. The app opens `checkout_url` in an in-app WebView and closes it when the provider redirects to our callback URL.
4. The app then polls `GET /api/payments/{reference}` until `paid` / `failed`.
5. **Crediting happens only on the server**, from a signature-verified webhook plus a server-side "verify transaction" call. The WebView redirect is never trusted.

## Providers
| Provider | Initialize | Webhook signature |
|---|---|---|
| Paystack | `POST /transaction/initialize` | HMAC-SHA512 of body, header `x-paystack-signature` |
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
Remove razorpay, stripe, paytabs, braintree, paypal, the Paystack fork and the Flutterwave SDK. `PaymentScreen` becomes: choose method, call initiate, open WebView, poll.

## Build order
1. Migration: wallets, wallet_ledger, payment_gateways (no secrets), payment_intents, payments.
2. Wallet endpoints (balance, history).
3. Paystack end to end (test mode), then Flutterwave, Korapay, Pocketfi.
4. App changes.
