import { Hono } from "hono";
import type { Client } from "pg";
import type { AppEnv } from "../env";
import { withDb } from "../db";
import { requireAuth } from "../auth/middleware";
import { hashPassword, verifyPassword } from "../auth/password";
import { userCurrency } from "../lib/currency";
import { InsufficientFunds, postToWallet, toMoney } from "../lib/wallet";
import { readBody, validationFailed } from "../lib/legacy";

export const walletTransferRoutes = new Hono<AppEnv>();

export type TransferSettings = { enabled: boolean; min: number; max: number; daily_limit: number };
const DEFAULTS: TransferSettings = { enabled: true, min: 100, max: 500_000, daily_limit: 1_000_000 };

export async function getTransferSettings(db: Client): Promise<TransferSettings> {
  const row = (await db.query("select value from app.settings where key = 'wallet_transfer'")).rows[0];
  return { ...DEFAULTS, ...(row?.value ?? {}) };
}

const MAX_PIN_TRIES = 5;
const LOCK_MINUTES = 15;

/** Four digits, and not something anyone would guess first (0000, 1234, 4321). */
const pinProblem = (pin: string): string | null => {
  if (!/^\d{4}$/.test(pin)) return "Use exactly 4 digits.";
  if (/^(\d)\1{3}$/.test(pin) || "01234567890".includes(pin) || "09876543210".includes(pin)) return "Choose a PIN that is harder to guess.";
  return null;
};

type PinState = { hash: string | null; failed: number; locked: Date | null };
const pinState = async (db: Client, userId: number): Promise<PinState> => {
  const r = (await db.query("select transaction_pin_hash, pin_failed_attempts, pin_locked_until from app.users where id = $1", [userId])).rows[0];
  return { hash: r?.transaction_pin_hash ?? null, failed: r?.pin_failed_attempts ?? 0, locked: r?.pin_locked_until ?? null };
};

/** Checks a PIN with the lockout rules. Returns null when it is right, otherwise what to tell the person. */
async function checkPin(db: Client, userId: number, pin: string): Promise<{ code: string; message: string } | null> {
  const st = await pinState(db, userId);
  if (!st.hash) return { code: "pin_not_set", message: "Create a transaction PIN first." };
  if (st.locked && st.locked.getTime() > Date.now()) {
    const mins = Math.ceil((st.locked.getTime() - Date.now()) / 60000);
    return { code: "pin_locked", message: `Too many wrong PINs. Try again in ${mins} minute${mins === 1 ? "" : "s"}.` };
  }
  if (await verifyPassword(db, pin, st.hash)) {
    if (st.failed) await db.query("update app.users set pin_failed_attempts = 0, pin_locked_until = null where id = $1", [userId]);
    return null;
  }
  const failed = st.failed + 1;
  if (failed >= MAX_PIN_TRIES) {
    await db.query("update app.users set pin_failed_attempts = 0, pin_locked_until = now() + ($2 || ' minutes')::interval where id = $1", [userId, String(LOCK_MINUTES)]);
    return { code: "pin_locked", message: `Too many wrong PINs. Try again in ${LOCK_MINUTES} minutes.` };
  }
  await db.query("update app.users set pin_failed_attempts = $2 where id = $1", [userId, failed]);
  const left = MAX_PIN_TRIES - failed;
  return { code: "pin_wrong", message: `Wrong PIN. ${left} ${left === 1 ? "try" : "tries"} left.` };
}

walletTransferRoutes.get("/wallet/pin", withDb, requireAuth, async (c) => {
  const st = await pinState(c.get("db"), c.get("user").id);
  return c.json({ has_pin: !!st.hash, locked: !!(st.locked && st.locked.getTime() > Date.now()) });
});

/** Create the PIN, or change it with the current PIN (or the account password if it was forgotten). */
walletTransferRoutes.post("/wallet/pin", withDb, requireAuth, async (c) => {
  const db = c.get("db");
  const me = c.get("user");
  const b = await readBody(c);
  const pin = String(b.pin ?? "");
  const problem = pinProblem(pin);
  if (problem) return validationFailed(c, { pin: [problem] });
  const st = await pinState(db, me.id);
  if (st.hash) {
    if (b.current_pin) {
      const bad = await checkPin(db, me.id, String(b.current_pin));
      if (bad) return c.json({ message: bad.message, code: bad.code }, 422);
    } else {
      const row = (await db.query("select password_hash from app.users where id = $1", [me.id])).rows[0];
      if (!b.password || !(await verifyPassword(db, String(b.password), row?.password_hash ?? null))) {
        return validationFailed(c, { current_pin: ["Enter your current PIN or your account password."] });
      }
    }
  }
  await db.query("update app.users set transaction_pin_hash = $2, pin_failed_attempts = 0, pin_locked_until = null where id = $1", [me.id, await hashPassword(db, pin)]);
  return c.json({ message: st.hash ? "PIN changed" : "PIN created" });
});

const publicName = (u: { first_name?: string; last_name?: string; display_name?: string; username: string }) => {
  const first = (u.first_name ?? u.display_name ?? "").trim();
  const last = (u.last_name ?? "").trim();
  return (first ? `${first}${last ? ` ${last[0]}.` : ""}` : u.username);
};

const findRecipient = async (db: Client, username: string, selfId: number) =>
  (await db.query(
    "select id, username, first_name, last_name, display_name from app.users where lower(username) = lower($1) and id <> $2 and status = 'active' and deleted_at is null",
    [username.replace(/^@/, "").trim(), selfId])).rows[0];

/** Lets the sender confirm who they are paying before they enter the PIN. Shows a first name and last initial only. */
walletTransferRoutes.get("/wallet/transfer/recipient", withDb, requireAuth, async (c) => {
  const r = await findRecipient(c.get("db"), String(c.req.query("username") ?? ""), c.get("user").id);
  return c.json(r ? { found: true, username: r.username, name: publicName(r) } : { found: false });
});

walletTransferRoutes.get("/wallet/transfer/settings", withDb, requireAuth, async (c) => c.json(await getTransferSettings(c.get("db"))));

walletTransferRoutes.post("/wallet/transfer", withDb, requireAuth, async (c) => {
  const db = c.get("db");
  const me = c.get("user");
  const b = await readBody(c);
  const settings = await getTransferSettings(db);
  if (!settings.enabled) return c.json({ message: "Transfers are switched off for now." }, 403);

  const amount = toMoney(b.amount);
  if (!amount) return validationFailed(c, { amount: ["Enter a valid amount."] });
  const n = Number(amount);
  if (n < settings.min) return validationFailed(c, { amount: [`The smallest transfer is ${settings.min}.`] });
  if (n > settings.max) return validationFailed(c, { amount: [`The largest single transfer is ${settings.max}.`] });
  const note = String(b.note ?? "").trim().slice(0, 140) || null;

  const to = await findRecipient(db, String(b.username ?? ""), me.id);
  if (!to) return validationFailed(c, { username: ["We could not find that username."] });

  if ((await userCurrency(db, me.id)) !== (await userCurrency(db, to.id))) return validationFailed(c, { username: ["That person's wallet is in a different currency, so you cannot send them money."] });

  const bad = await checkPin(db, me.id, String(b.pin ?? ""));
  if (bad) return c.json({ message: bad.message, code: bad.code }, bad.code === "pin_not_set" ? 409 : 422);

  const today = Number((await db.query("select coalesce(sum(amount),0) s from app.wallet_transfers where sender_id = $1 and created_at > now() - interval '24 hours'", [me.id])).rows[0].s);
  if (today + n > settings.daily_limit) return validationFailed(c, { amount: [`This would pass your daily limit of ${settings.daily_limit}.`] });

  const ref = crypto.randomUUID();
  try {
    await db.query("begin");
    const out = await postToWallet(db, {
      userId: me.id, direction: "debit", amount, kind: "transfer_out", idempotencyKey: `transfer-out:${ref}`,
      description: `Sent to @${to.username}`, meta: { to: to.id, note },
    });
    await postToWallet(db, {
      userId: to.id, direction: "credit", amount, kind: "transfer_in", idempotencyKey: `transfer-in:${ref}`,
      description: `Received from @${me.username}`, meta: { from: me.id, note },
    });
    const t = (await db.query("insert into app.wallet_transfers (sender_id, recipient_id, amount, note) values ($1,$2,$3,$4) returning id", [me.id, to.id, amount, note])).rows[0];
    await db.query("commit");
    return c.json({ message: `Sent ${amount} to @${to.username}`, balance: Number(out.balance), transfer: { id: Number(t.id), amount: n, to: { username: to.username, name: publicName(to) } } });
  } catch (err) {
    await db.query("rollback").catch(() => undefined);
    if (err instanceof InsufficientFunds) return validationFailed(c, { amount: ["You do not have enough balance for this transfer."] });
    throw err;
  }
});
