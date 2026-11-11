import { Hono } from "hono";
import type { AppEnv } from "../env";
import { UNIQUE_VIOLATION, withDb } from "../db";
import { requireAuth } from "../auth/middleware";
import { loadGateway, loadSecrets } from "../lib/gateway-creds";
import { createStaticAccount, normalizePhone, pocketfiBase, resolveCustomers, verifySignature } from "../lib/pocketfi";
import { postToWallet, toMoney } from "../lib/wallet";
import { getGlobalMinBalance } from "../lib/commission";

export const walletRoutes = new Hono<AppEnv>();

const num = (v: unknown) => (v === null || v === undefined ? 0 : Number(v));
/** Which wallet the app is looking at: the driver wallet in Driver mode, the rider wallet otherwise. */
const kindOf = (u: Record<string, unknown>): "rider" | "driver" => (u.active_mode === "driver" ? "driver" : "rider");

/** Legacy "wallet-detail": the signed-in user's balance. */
walletRoutes.get("/wallet-detail", withDb, requireAuth, async (c) => {
  const me = c.get("user");
  const w = (await c.get("db").query("select id, user_id, balance, currency, created_at, updated_at from app.wallets where user_id = $1 and kind = $2", [me.id, kindOf(me)])).rows[0];
  const balance = num(w?.balance);
  // Drivers below this balance cannot take new trips (the driver app reads this legacy field).
  const minToGetRide = kindOf(me) === "driver" ? await getGlobalMinBalance(c.get("db")) : 0;
  return c.json({
    wallet_data: { id: w?.id ?? 0, user_id: me.id, total_amount: balance, total_withdrawn: 0, currency: w?.currency ?? "NGN", created_at: w?.created_at ?? null, updated_at: w?.updated_at ?? null },
    min_amount_to_get_ride: minToGetRide,
    total_amount: balance,
  });
});

/** Legacy "wallet-list": ledger, newest first, with the legacy field names the apps read. */
walletRoutes.get("/wallet-list", withDb, requireAuth, async (c) => {
  const me = c.get("user");
  const db = c.get("db");
  const perPage = Math.min(Math.max(Number(c.req.query("per_page")) || 20, 1), 100);
  const page = Math.max(Number(c.req.query("page")) || 1, 1);
  const kind = kindOf(me);
  const total = (await db.query("select count(*)::int n from app.wallet_ledger l join app.wallets w on w.id = l.wallet_id where w.user_id = $1 and w.kind = $2", [me.id, kind])).rows[0].n;
  const rows = (await db.query(
    `select l.id, l.direction, l.amount, l.balance_after, l.kind, l.description, l.ride_request_id, l.created_at, w.currency
       from app.wallet_ledger l join app.wallets w on w.id = l.wallet_id
      where w.user_id = $1 and w.kind = $2 order by l.created_at desc, l.id desc limit $3 offset $4`,
    [me.id, kind, perPage, (page - 1) * perPage])).rows;
  const w = (await db.query("select id, user_id, balance, currency, created_at, updated_at from app.wallets where user_id = $1 and kind = $2", [me.id, kind])).rows[0];
  const name = me.display_name ?? `${me.first_name ?? ""} ${me.last_name ?? ""}`.trim();
  return c.json({
    data: rows.map((r) => ({
      id: r.id, user_id: me.id, amount: num(r.amount), balance: num(r.balance_after), wallet_balance: num(r.balance_after),
      currency: r.currency, description: r.description, ride_request_id: r.ride_request_id,
      type: r.direction, transaction_type: r.kind, datetime: r.created_at, created_at: r.created_at, updated_at: r.created_at, user_display_name: name,
    })),
    pagination: { currentPage: page, per_page: perPage, totalPages: Math.max(Math.ceil(total / perPage), 1), total_items: total },
    wallet_balance: { id: w?.id ?? 0, user_id: me.id, total_amount: num(w?.balance), total_withdrawn: 0, currency: w?.currency ?? "NGN", collected_cash: "0", created_at: w?.created_at ?? null, updated_at: w?.updated_at ?? null },
  });
});

/** Legacy "payment-gateway-list": which methods to show. Never includes keys. */
walletRoutes.get("/payment-gateway-list", withDb, requireAuth, async (c) => {
  const rows = (await c.get("db").query(
    "select id, type, title, status, is_test, created_at, updated_at from app.payment_gateways where status = true order by sort_order, id")).rows;
  return c.json({
    data: rows.map((g) => ({ id: g.id, type: g.type, title: g.title, status: 1, is_test: g.is_test ? 1 : 0, gateway_image: null, live_value: null, test_value: null, created_at: g.created_at, updated_at: g.updated_at })),
    pagination: { currentPage: 1, per_page: rows.length, totalPages: 1, total_items: rows.length },
  });
});

/**
 * The user's own bank account for topping up the wallet by transfer. Created at Pocketfi the first
 * time it is asked for, then reused. The app shows the number with a Copy button.
 */
walletRoutes.get("/wallet/virtual-account", withDb, requireAuth, async (c) => {
  const me = c.get("user");
  const db = c.get("db");
  const kind = kindOf(me);
  const shape = (r: Record<string, string>) => ({ data: { provider: r.provider, bank_name: r.bank_name, account_number: r.account_number, account_name: r.account_name } });

  const existing = (await db.query("select provider, bank_name, account_number, account_name from app.virtual_accounts where user_id = $1 and wallet_kind = $2 and provider = 'pocketfi' and status = 'active' limit 1", [me.id, kind])).rows[0];
  if (existing) return c.json(shape(existing));

  const gw = await loadGateway(db, "pocketfi", c.env.SETTINGS_ENCRYPTION_KEY).catch(() => null);
  if (!gw || !gw.enabled || !gw.creds.api_token || !gw.creds.business_id) {
    return c.json({ message: "Bank transfer top-up is not available yet.", status: 503 }, 503);
  }
  const phone = normalizePhone(me.contact_number as string | null);
  if (!phone) return c.json({ message: "Add your phone number in your profile to get a bank account number.", status: 422 }, 422);
  if (!me.first_name || !me.last_name || !me.email) return c.json({ message: "Complete your name and email in your profile first.", status: 422 }, 422);

  const base = pocketfiBase(gw.isTest, c.env.POCKETFI_BASE_URL);
  const acct = await createStaticAccount(base, gw.creds, { first_name: String(me.first_name), last_name: String(me.last_name), phone, email: me.email ? String(me.email) : `${me.username}@users.drop.ng` });
  if (!acct) return c.json({ message: "Could not create your account number right now. Please try again shortly.", status: 502 }, 502);

  try {
    await db.query(
      "insert into app.virtual_accounts (user_id, wallet_kind, provider, bank_name, account_number, account_name) values ($1,$5,'pocketfi',$2,$3,$4)",
      [me.id, acct.bankName, acct.accountNumber, acct.accountName, kind]);
  } catch (e) {
    if ((e as { code?: string }).code !== UNIQUE_VIOLATION) throw e; // a parallel request saved it first
  }
  c.executionCtx.waitUntil(resolveCustomers(db, base, gw.creds).catch(() => 0));
  const saved = (await db.query("select provider, bank_name, account_number, account_name from app.virtual_accounts where user_id = $1 and wallet_kind = $2 and provider = 'pocketfi' limit 1", [me.id, kind])).rows[0];
  return c.json(shape(saved));
});

/**
 * Pocketfi tells us a transfer arrived. Nothing is trusted until the HMAC-SHA512 signature of the
 * raw body checks out. The wallet is credited once per transaction reference, however often it is sent.
 */
walletRoutes.post("/webhooks/pocketfi", withDb, async (c) => {
  const db = c.get("db");
  const raw = await c.req.text();
  const secrets = await loadSecrets(db, "pocketfi", "secret_key", c.env.SETTINGS_ENCRYPTION_KEY).catch(() => []);
  const sig = c.req.header("pocketfi-signature") ?? c.req.header("http_pocketfi_signature");
  if (!(await verifySignature(raw, sig, secrets))) return c.json({ message: "Invalid signature" }, 400);

  let p: any;
  try { p = JSON.parse(raw); } catch { return c.json({ message: "Bad payload" }, 400); }
  const reference = typeof p?.transaction?.reference === "string" ? p.transaction.reference : null;
  if (!reference) return c.json({ message: "Missing reference" }, 400);

  const amount = toMoney(p?.order?.amount);
  const fee = toMoney(p?.order?.fee) ?? "0.00";
  const customerId = p?.customer?.id != null ? String(p.customer.id) : null;

  try {
    await db.query("begin");
    const ev = await db.query(
      `insert into app.payment_events (provider, provider_reference, amount, fee, payload)
       values ('pocketfi', $1, $2, $3, $4::jsonb) on conflict (provider, provider_reference) do nothing returning id`,
      [reference, amount, fee, JSON.stringify(p)]);
    if (!ev.rowCount) { await db.query("commit"); return c.json({ message: "success", duplicate: true }); }
    const eventId = ev.rows[0].id;

    const flag = async (note: string) => {
      await db.query("update app.payment_events set status = 'flagged', note = $2 where id = $1", [eventId, note]);
      await db.query("commit");
      return c.json({ message: "success", flagged: true });
    };
    if (!amount) return await flag("Amount missing or invalid");
    if (!customerId) return await flag("No customer id in payload");

    const find = async () => (await db.query("select user_id, wallet_kind from app.virtual_accounts where provider = 'pocketfi' and provider_customer = $1 limit 1", [customerId])).rows[0];
    let owner = await find();
    if (!owner) {
      // The customer id is learned lazily from Pocketfi's accounts list. Try that once before flagging.
      const gw = await loadGateway(db, "pocketfi", c.env.SETTINGS_ENCRYPTION_KEY).catch(() => null);
      if (gw?.creds.api_token && gw.creds.business_id) {
        await resolveCustomers(db, pocketfiBase(gw.isTest, c.env.POCKETFI_BASE_URL), gw.creds).catch(() => 0);
        owner = await find();
      }
    }
    if (!owner) return await flag("Unknown customer: no wallet matches this account");

    await postToWallet(db, {
      userId: owner.user_id, wallet: owner.wallet_kind, direction: "credit", amount, kind: "topup", idempotencyKey: `pocketfi:${reference}`,
      description: "Wallet top-up by bank transfer", meta: { provider: "pocketfi", reference, fee },
    });
    await db.query("update app.payment_events set status = 'credited', user_id = $2 where id = $1", [eventId, owner.user_id]);
    await db.query("commit");
    return c.json({ message: "success" });
  } catch (e) {
    await db.query("rollback").catch(() => undefined);
    console.error("pocketfi webhook failed", (e as Error).message);
    return c.json({ message: "Temporary error, please retry" }, 500); // Pocketfi retries up to 5 times
  }
});
