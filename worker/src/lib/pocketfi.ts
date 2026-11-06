import type { Client } from "pg";

export const POCKETFI_BANK = "kuda"; // static account; BVN/NIN optional for Kuda

export function pocketfiBase(isTest: boolean, override?: string): string {
  return override || (isTest ? "https://api.pocketfi.ng/api/test" : "https://api.pocketfi.ng/api/v1");
}

type Creds = { business_id?: string; api_token?: string; secret_key?: string };

async function call(method: "GET" | "POST", url: string, token: string, body?: unknown): Promise<{ ok: boolean; json: any }> {
  try {
    const r = await fetch(url, {
      method,
      headers: { Authorization: `Bearer ${token}`, Accept: "application/json", ...(body ? { "Content-Type": "application/json" } : {}) },
      body: body ? JSON.stringify(body) : undefined,
    });
    return { ok: r.ok, json: await r.json().catch(() => ({})) };
  } catch {
    return { ok: false, json: {} };
  }
}

/** Nigerian mobile as 11 digits starting 0, or null. */
export function normalizePhone(raw: string | null | undefined): string | null {
  const d = String(raw ?? "").replace(/\D/g, "");
  const n = d.startsWith("234") ? "0" + d.slice(3) : d.length === 10 ? "0" + d : d;
  return /^0\d{10}$/.test(n) ? n : null;
}

export async function createStaticAccount(
  base: string, c: Creds, u: { first_name: string; last_name: string; phone: string; email: string },
): Promise<{ bankName: string; accountNumber: string; accountName: string } | null> {
  const r = await call("POST", `${base}/virtual-accounts/create`, c.api_token!, {
    first_name: u.first_name, last_name: u.last_name, phone: u.phone, email: u.email,
    businessId: String(c.business_id), bank: POCKETFI_BANK,
  });
  const b = r.json?.banks?.[0];
  if (!r.ok || r.json?.status !== true || !b?.accountNumber) return null;
  return { bankName: String(b.bankName ?? POCKETFI_BANK), accountNumber: String(b.accountNumber), accountName: String(b.accountName ?? `${u.first_name} ${u.last_name}`) };
}

/**
 * Pocketfi's create call does not return the customer id that its webhooks carry. The accounts list does
 * (user_id per account), so match by account number and remember it. Safe to call repeatedly.
 */
export async function resolveCustomers(db: Client, base: string, c: Creds): Promise<number> {
  const pending = (await db.query("select id, account_number from app.virtual_accounts where provider = 'pocketfi' and provider_customer is null")).rows;
  if (!pending.length) return 0;
  const r = await call("GET", `${base}/virtual-accounts/fetch?businessId=${encodeURIComponent(String(c.business_id))}`, c.api_token!);
  const accounts: { account: string; user_id: number }[] = Array.isArray(r.json?.accounts) ? r.json.accounts : [];
  let n = 0;
  for (const p of pending) {
    const hit = accounts.find((a) => String(a.account) === String(p.account_number));
    if (hit?.user_id != null) {
      await db.query("update app.virtual_accounts set provider_customer = $2 where id = $1", [p.id, String(hit.user_id)]);
      n++;
    }
  }
  return n;
}

/** HMAC-SHA512 of the raw body, hex, compared in constant time. */
export async function verifySignature(rawBody: string, signature: string | undefined, secrets: string[]): Promise<boolean> {
  if (!signature || !secrets.length) return false;
  const enc = new TextEncoder();
  for (const secret of secrets) {
    const key = await crypto.subtle.importKey("raw", enc.encode(secret), { name: "HMAC", hash: "SHA-512" }, false, ["sign"]);
    const mac = new Uint8Array(await crypto.subtle.sign("HMAC", key, enc.encode(rawBody)));
    const hex = [...mac].map((b) => b.toString(16).padStart(2, "0")).join("");
    if (hex.length === signature.length) {
      let diff = 0;
      for (let i = 0; i < hex.length; i++) diff |= hex.charCodeAt(i) ^ signature.toLowerCase().charCodeAt(i);
      if (diff === 0) return true;
    }
  }
  return false;
}
