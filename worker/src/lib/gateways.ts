/** Which credentials each gateway needs. `secret` fields are write-only in the admin UI. */
export type GatewayField = { key: string; label: string; secret: boolean; hint?: string };

export const GATEWAY_FIELDS: Record<string, GatewayField[]> = {
  pocketfi: [
    { key: "business_id", label: "Business ID", secret: false },
    { key: "api_token", label: "API token", secret: true, hint: "Settings > API Keys. Used as the Bearer token." },
    { key: "secret_key", label: "Secret key (webhook signing)", secret: true, hint: "Verifies the Pocketfi-Signature on webhooks." },
  ],
  korapay: [
    { key: "public_key", label: "Public key", secret: false },
    { key: "secret_key", label: "Secret key", secret: true },
  ],
  paystack: [
    { key: "public_key", label: "Public key", secret: false },
    { key: "secret_key", label: "Secret key", secret: true },
  ],
  flutterwave: [
    { key: "public_key", label: "Public key", secret: false },
    { key: "secret_key", label: "Secret key", secret: true },
    { key: "secret_hash", label: "Webhook secret hash", secret: true },
  ],
  resend: [
    { key: "api_key", label: "Resend API key", secret: true, hint: "Resend dashboard > API Keys. Sends the password-reset codes." },
    { key: "from_email", label: "From address", secret: false, hint: "e.g. DROP <no-reply@yourdomain.com>. Needs a domain verified in Resend." },
  ],
  wallet: [],
  cash: [],
};
