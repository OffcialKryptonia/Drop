import { Hono } from "hono";
import type { AppEnv } from "../env";
import { withDb } from "../db";
import { requireAuth } from "../auth/middleware";
import { audit, guard } from "../lib/permissions";
import { InsufficientFunds, postToWallet, toMoney } from "../lib/wallet";
import { readBody, validationFailed } from "../lib/legacy";

export const payoutRoutes = new Hono<AppEnv>();
export const adminPayoutRoutes = new Hono<AppEnv>();

export const getPayoutSettings = async (db: import("pg").Client) => {
  const v = (await db.query("select value from app.settings where key = 'payouts'")).rows[0]?.value ?? {};
  return { enabled: v.enabled !== false, min_amount: Number(v.min_amount ?? 1000) };
};
const STATUS_NUM: Record<string, number> = { pending: 0, paid: 1, declined: 2 }; // what the app's list expects

/** Driver asks to be paid out. Legacy name kept because the driver wallet screen calls it. */
payoutRoutes.post("/save-withdrawrequest", withDb, requireAuth, async (c) => {
  const db = c.get("db");
  const me = c.get("user");
  if (me.user_type !== "driver" && !(await db.query("select 1 from app.driver_profiles where user_id = $1 and status = 'approved'", [me.id])).rowCount)
    return c.json({ status: false, message: "Only approved drivers can request a payout." }, 403);
  const settings = await getPayoutSettings(db);
  if (!settings.enabled) return c.json({ status: false, message: "Payouts are paused for now. Please try again later." }, 403);
  const b = await readBody(c);
  const amount = toMoney(b.amount);
  if (!amount) return validationFailed(c, { amount: ["Enter an amount."] });
  if (Number(amount) < settings.min_amount) return validationFailed(c, { amount: [`The smallest payout is ${settings.min_amount.toLocaleString("en-NG")}.`] });
  const bank = (await db.query("select bank_name, bank_code, account_number, account_holder_name from app.user_bank_accounts where user_id = $1", [me.id])).rows[0];
  if (!bank?.account_number) return c.json({ status: false, message: "Add your bank details first (menu → Bank info)." }, 422);

  await db.query("begin");
  try {
    const w = (await db.query("select balance, currency from app.wallets where user_id = $1 and kind = 'driver' for update", [me.id])).rows[0];
    if (!w || Number(w.balance) < Number(amount)) { await db.query("rollback"); return c.json({ status: false, message: "Your wallet balance is lower than this amount." }, 422); }
    if ((await db.query("select 1 from app.withdraw_requests where user_id = $1 and status = 'pending'", [me.id])).rowCount) {
      await db.query("rollback");
      return c.json({ status: false, message: "You already have a payout waiting. Wait for it to be paid before asking again." }, 409);
    }
    const id = (await db.query(
      "insert into app.withdraw_requests (user_id, amount, currency, bank_name, bank_code, account_number, account_name) values ($1,$2,$3,$4,$5,$6,$7) returning id",
      [me.id, amount, String(w.currency).trim(), bank.bank_name, bank.bank_code, bank.account_number, bank.account_holder_name])).rows[0].id;
    await postToWallet(db, { userId: me.id, direction: "debit", amount, kind: "withdrawal", wallet: "driver", allowNegative: true, idempotencyKey: `withdraw:${id}`, description: "Payout request" });
    await db.query("commit");
  } catch (e) {
    await db.query("rollback").catch(() => undefined);
    if (e instanceof InsufficientFunds) return c.json({ status: false, message: "Your wallet balance is lower than this amount." }, 422);
    throw e;
  }
  return c.json({ status: true, message: "Payout requested. It will be sent to your bank account once approved." });
});

/** The driver's own payout history, in the shape the older wallet screen reads. */
payoutRoutes.get("/withdrawrequest-list", withDb, requireAuth, async (c) => {
  const db = c.get("db");
  const me = c.get("user");
  const page = Math.max(Number(c.req.query("page")) || 1, 1);
  const total = (await db.query("select count(*)::int n from app.withdraw_requests where user_id = $1", [me.id])).rows[0].n;
  const rows = (await db.query("select id, amount, currency, status, created_at, processed_at from app.withdraw_requests where user_id = $1 order by id desc limit 20 offset $2", [me.id, (page - 1) * 20])).rows;
  const w = (await db.query("select id, balance, currency, created_at, updated_at from app.wallets where user_id = $1 and kind = 'driver'", [me.id])).rows[0];
  const withdrawn = (await db.query("select coalesce(sum(amount),0) s from app.withdraw_requests where user_id = $1 and status = 'paid'", [me.id])).rows[0].s;
  return c.json({
    data: rows.map((r) => ({ id: Number(r.id), user_id: me.id, user_display_name: me.display_name, amount: Number(r.amount), currency: String(r.currency).trim(), status: STATUS_NUM[r.status], created_at: r.created_at, updated_at: r.processed_at ?? r.created_at })),
    pagination: { currentPage: page, per_page: 20, totalPages: Math.max(Math.ceil(total / 20), 1), total_items: total },
    wallet_balance: { id: Number(w?.id ?? 0), user_id: me.id, total_amount: Number(w?.balance ?? 0), total_withdrawn: Number(withdrawn), currency: String(w?.currency ?? "NGN").trim(), collected_cash: 0, manual_received: 0, online_received: 0, created_at: w?.created_at ?? null, updated_at: w?.updated_at ?? null },
  });
});

// ---------- Admin ----------

adminPayoutRoutes.get("/admin/payouts", ...guard("payout list"), async (c) => {
  const db = c.get("db");
  const status = ["pending", "paid", "declined"].includes(String(c.req.query("status"))) ? String(c.req.query("status")) : "pending";
  const page = Math.max(Number(c.req.query("page")) || 1, 1);
  const total = (await db.query("select count(*)::int n from app.withdraw_requests where status = $1", [status])).rows[0].n;
  const rows = (await db.query(
    `select w.id, w.amount, w.currency, w.status, w.bank_name, w.account_number, w.account_name, w.admin_note, w.created_at, w.processed_at, u.display_name as driver, u.username
       from app.withdraw_requests w join app.users u on u.id = w.user_id where w.status = $1 order by w.id desc limit 30 offset $2`, [status, (page - 1) * 30])).rows;
  return c.json({ settings: await getPayoutSettings(db), data: rows, pagination: { page, total_pages: Math.max(Math.ceil(total / 30), 1), total } });
});

adminPayoutRoutes.put("/admin/payouts/settings", ...guard("payout edit"), async (c) => {
  const b = await readBody(c);
  const min = Number(b.min_amount);
  if (!Number.isFinite(min) || min <= 0) return validationFailed(c, { min_amount: ["Enter an amount above zero."] });
  await c.get("db").query("insert into app.settings (key, value) values ('payouts', $1::jsonb) on conflict (key) do update set value = excluded.value", [JSON.stringify({ enabled: b.enabled !== false, min_amount: min })]);
  return c.json({ message: "Saved" });
});

/** Mark paid (you sent the money) or decline (the amount goes back to the driver's wallet). */
adminPayoutRoutes.put("/admin/payouts/:id", ...guard("payout edit"), async (c) => {
  const db = c.get("db");
  const admin = c.get("user");
  const id = Number(c.req.param("id"));
  const b = await readBody(c);
  const action = String(b.action);
  const note = String(b.note ?? "").trim().slice(0, 300) || null;
  if (action !== "paid" && action !== "declined") return validationFailed(c, { action: ["Choose paid or declined."] });
  if (action === "declined" && !note) return validationFailed(c, { note: ["Tell the driver why it was declined."] });
  await db.query("begin");
  try {
    const r = (await db.query("select id, user_id, amount, status from app.withdraw_requests where id = $1 for update", [id])).rows[0];
    if (!r) { await db.query("rollback"); return c.json({ message: "Not found" }, 404); }
    if (r.status !== "pending") { await db.query("rollback"); return c.json({ message: "This payout was already handled." }, 409); }
    await db.query("update app.withdraw_requests set status = $2, admin_note = $3, processed_at = now(), processed_by = $4 where id = $1", [id, action, note, admin.id]);
    if (action === "declined") {
      await postToWallet(db, { userId: Number(r.user_id), direction: "credit", amount: toMoney(r.amount)!, kind: "refund", wallet: "driver", idempotencyKey: `withdraw-refund:${id}`, description: "Payout declined" });
    }
    await db.query("commit");
  } catch (e) { await db.query("rollback").catch(() => undefined); throw e; }
  await audit(c, "payout", String(id), { action });
  return c.json({ message: action === "paid" ? "Marked as paid" : "Declined and returned to the driver's wallet" });
});
