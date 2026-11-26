import type { Client } from "pg";
import { loadGateway } from "./gateway-creds";

export type EmailTransport = { sent: boolean; error?: string; retryable?: boolean; providerId?: string; status?: number };

/**
 * One email through Resend using the keys saved in Admin. Never throws.
 * `retryable` is true only for failures that can clear by themselves: no network, 429, 5xx.
 * A refusal such as an unverified sending domain or a bad address is NOT retryable.
 * The idempotency key makes Resend treat a repeated request as the same email, so a retry cannot deliver it twice.
 */
export async function deliverEmail(db: Client, encKey: string | undefined,
  m: { to: string; subject: string; html: string; text?: string; idempotencyKey?: string }): Promise<EmailTransport> {
  const gw = await loadGateway(db, "resend", encKey).catch(() => null);
  if (!gw || !gw.enabled || !gw.creds.api_key || !gw.creds.from_email) return { sent: false, error: "Email is not set up yet: add the Resend key and from-address in Admin." };
  try {
    const headers: Record<string, string> = { Authorization: `Bearer ${gw.creds.api_key}`, "Content-Type": "application/json" };
    if (m.idempotencyKey) headers["Idempotency-Key"] = m.idempotencyKey;
    const r = await fetch("https://api.resend.com/emails", {
      method: "POST", headers,
      body: JSON.stringify({ from: gw.creds.from_email, to: [m.to], subject: m.subject, html: m.html, ...(m.text ? { text: m.text } : {}) }),
    });
    const body = await r.text();
    let json: { id?: string; message?: string; name?: string } = {};
    try { json = JSON.parse(body); } catch { /* not json */ }
    if (!r.ok || !json.id) {
      const why = json.message || body;
      console.error("resend refused", r.status, why.slice(0, 200));
      return { sent: false, status: r.status, error: `Resend said (${r.status}): ${why.slice(0, 200)}`, retryable: r.status === 429 || r.status >= 500 };
    }
    return { sent: true, status: r.status, providerId: json.id };
  } catch (e) {
    console.error("resend failed", (e as Error).message);
    return { sent: false, error: (e as Error).message, retryable: true };
  }
}

/** Sends one plain email (no template, no delivery log). Used for admin alerts. Returns false when not configured or refused. */
export async function sendEmail(db: Client, encKey: string | undefined, m: { to: string; subject: string; html: string }): Promise<boolean> {
  return (await deliverEmail(db, encKey, m)).sent;
}
