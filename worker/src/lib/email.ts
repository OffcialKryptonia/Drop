import type { Client } from "pg";
import { loadGateway } from "./gateway-creds";

/** Sends one email through Resend using the keys saved in Admin. Returns false when not configured or refused. */
export async function sendEmail(db: Client, encKey: string | undefined, m: { to: string; subject: string; html: string }): Promise<boolean> {
  const gw = await loadGateway(db, "resend", encKey).catch(() => null);
  if (!gw || !gw.enabled || !gw.creds.api_key || !gw.creds.from_email) return false;
  try {
    const r = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: { Authorization: `Bearer ${gw.creds.api_key}`, "Content-Type": "application/json" },
      body: JSON.stringify({ from: gw.creds.from_email, to: [m.to], subject: m.subject, html: m.html }),
    });
    if (!r.ok) console.error("resend refused", r.status, (await r.text()).slice(0, 200));
    return r.ok;
  } catch (e) {
    console.error("resend failed", (e as Error).message);
    return false;
  }
}
