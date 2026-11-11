import { Hono } from "hono";
import type { AppEnv } from "../env";
import { withDb } from "../db";
import { requireAuth } from "../auth/middleware";
import { loadGateway } from "../lib/gateway-creds";
import { requireApprovedDriver } from "../lib/roles";
import { readBody, validationFailed } from "../lib/legacy";

export const bankRoutes = new Hono<AppEnv>();
const KORAPAY = "https://api.korapay.com";

/** Active Nigerian banks, A to Z. */
bankRoutes.get("/banks", withDb, requireAuth, async (c) => {
  const rows = (await c.get("db").query("select code, name, kind, logo_url from app.banks where active order by name")).rows;
  return c.json({ data: rows });
});

type Resolved = { ok: true; name: string } | { ok: false; reason: "not_configured" | "not_found" };

/** Asks Korapay who owns an account. Uses the key saved in Admin > Payment methods. */
async function resolveAccount(c: any, bankCode: string, account: string): Promise<Resolved> {
  const gw = await loadGateway(c.get("db"), "korapay", c.env.SETTINGS_ENCRYPTION_KEY).catch(() => null);
  const key = gw?.creds.secret_key;
  if (!gw || !key) return { ok: false, reason: "not_configured" };
  try {
    const res = await fetch(`${KORAPAY}/merchant/api/v1/misc/banks/resolve`, {
      method: "POST",
      headers: { Authorization: `Bearer ${key}`, "Content-Type": "application/json" },
      body: JSON.stringify({ bank: bankCode, account, currency: "NGN" }),
    });
    const j = (await res.json().catch(() => null)) as { status?: boolean; data?: { account_name?: string } } | null;
    const name = j?.data?.account_name;
    return res.ok && j?.status && name ? { ok: true, name: String(name) } : { ok: false, reason: "not_found" };
  } catch {
    return { ok: false, reason: "not_configured" };
  }
}

const validAccount = (n: unknown) => typeof n === "string" && /^\d{10}$/.test(n.trim());

/** Account name lookup. When no gateway key is set the app lets the person type the name instead. */
bankRoutes.post("/bank/resolve", withDb, requireAuth, async (c) => {
  const b = await readBody(c);
  const code = String(b.bank_code ?? "").trim();
  const account = String(b.account_number ?? "").trim();
  if (!code || !validAccount(account)) return validationFailed(c, { account_number: ["Enter the 10-digit account number."] });
  const r = await resolveAccount(c, code, account);
  return c.json(r.ok ? { resolved: true, account_name: r.name } : { resolved: false, reason: r.reason });
});

const mine = async (c: any) => {
  const row = (await c.get("db").query(
    "select bank_code, bank_name, account_number, account_holder_name, verified from app.user_bank_accounts where user_id = $1", [c.get("user").id])).rows[0];
  return row ? { bank_code: row.bank_code, bank_name: row.bank_name, account_number: row.account_number, account_name: row.account_holder_name, verified: row.verified } : null;
};

/** The driver's payout account. Passengers do not get paid, so only approved drivers can use these. */
bankRoutes.get("/bank/account", withDb, requireAuth, requireApprovedDriver, async (c) => c.json({ data: await mine(c) }));

bankRoutes.on(["PUT", "POST"], "/bank/account", withDb, requireAuth, requireApprovedDriver, async (c) => {
  const db = c.get("db");
  const b = await readBody(c);
  const code = String(b.bank_code ?? "").trim();
  const account = String(b.account_number ?? "").trim();
  const bank = (await db.query("select name from app.banks where code = $1 and active", [code])).rows[0];
  if (!bank) return validationFailed(c, { bank_code: ["Choose your bank from the list."] });
  if (!validAccount(account)) return validationFailed(c, { account_number: ["Enter the 10-digit account number."] });

  // The bank's own answer wins; a typed name is only accepted when lookup is not set up.
  const r = await resolveAccount(c, code, account);
  let name: string, verified = false;
  if (r.ok) { name = r.name; verified = true; }
  else if (r.reason === "not_found") return validationFailed(c, { account_number: ["We could not find this account. Check the bank and number."] });
  else {
    name = String(b.account_name ?? "").trim().slice(0, 120);
    if (!name) return validationFailed(c, { account_name: ["Enter the account name."] });
  }
  await db.query(
    `insert into app.user_bank_accounts (user_id, bank_name, bank_code, account_holder_name, account_number, verified)
     values ($1, $2, $3, $4, $5, $6)
     on conflict (user_id) do update set bank_name = $2, bank_code = $3, account_holder_name = $4, account_number = $5,
       verified = $6, routing_number = null, bank_iban = null, bank_swift = null, updated_at = now()`,
    [c.get("user").id, bank.name, code, name, account, verified]);
  return c.json({ message: "Bank account saved", data: await mine(c) });
});
