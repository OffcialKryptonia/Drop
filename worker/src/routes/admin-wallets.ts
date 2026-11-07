import { Hono, type Context } from "hono";
import { z } from "zod";
import type { AppEnv } from "../env";
import { audit, guard } from "../lib/permissions";
import { readBody, validationFailed } from "../lib/legacy";
import { getGlobalMinBalance } from "../lib/commission";
import { postToWallet, toMoney } from "../lib/wallet";

export const adminWalletRoutes = new Hono<AppEnv>();
type C = Context<AppEnv>;
const idParam = (c: C) => { const n = Number(c.req.param("id")); return Number.isInteger(n) && n > 0 ? n : null; };
const zodErrors = (e: z.ZodError) => {
  const out: Record<string, string[]> = {};
  for (const i of e.issues) (out[String(i.path.join(".") || "body")] ??= []).push(i.message);
  return out;
};

/** Drivers with their wallet balance; "blocked" means below the minimum, so no new trips. */
adminWalletRoutes.get("/admin/driver-wallets", ...guard("driver_wallet list"), async (c) => {
  const db = c.get("db");
  const min = await getGlobalMinBalance(db);
  const filter = c.req.query("filter") === "all" ? "all" : "blocked";
  const q = (c.req.query("q") ?? "").trim();
  const perPage = Math.min(Math.max(Number(c.req.query("per_page")) || 20, 1), 100);
  const page = Math.max(Number(c.req.query("page")) || 1, 1);

  const where = ["'driver' = any(u.roles)", "u.deleted_at is null", "$1::numeric is not null"];
  const params: unknown[] = [min];
  if (filter === "blocked") where.push("coalesce(w.balance, 0) < $1::numeric");
  if (q) { params.push(`%${q}%`); where.push(`(u.email ilike $${params.length} or u.first_name ilike $${params.length} or u.last_name ilike $${params.length} or u.contact_number ilike $${params.length})`); }
  const from = `from app.users u left join app.wallets w on w.user_id = u.id and w.kind = 'driver' where ${where.join(" and ")}`;
  const total = (await db.query(`select count(*)::int n ${from}`, params)).rows[0].n;
  const rows = (await db.query(
    `select u.id, u.first_name, u.last_name, u.email, u.contact_number, u.status, coalesce(w.balance, 0) as balance, coalesce(w.balance, 0) < $1::numeric as blocked
       ${from} order by coalesce(w.balance, 0) asc, u.id limit ${perPage} offset ${(page - 1) * perPage}`, params)).rows;
  return c.json({
    minimum: min, filter,
    data: rows.map((r) => ({ ...r, balance: Number(r.balance) })),
    pagination: { page, per_page: perPage, total, total_pages: Math.max(Math.ceil(total / perPage), 1) },
  });
});

adminWalletRoutes.get("/admin/driver-wallets/:id/ledger", ...guard("driver_wallet list"), async (c) => {
  const id = idParam(c); if (!id) return c.json({ message: "Not found" }, 404);
  const rows = (await c.get("db").query(
    "select l.id, l.direction, l.amount, l.balance_after, l.kind, l.description, l.created_at from app.wallet_ledger l join app.wallets w on w.id = l.wallet_id where w.user_id = $1 and w.kind = 'driver' order by l.created_at desc, l.id desc limit 30", [id])).rows;
  return c.json({ data: rows.map((r) => ({ ...r, amount: Number(r.amount), balance_after: Number(r.balance_after) })) });
});

adminWalletRoutes.get("/admin/wallet-settings", ...guard("driver_wallet list"), async (c) =>
  c.json({ driver_min_wallet_balance: await getGlobalMinBalance(c.get("db")) }));

adminWalletRoutes.put("/admin/wallet-settings", ...guard("driver_wallet edit"), async (c) => {
  const p = z.object({ driver_min_wallet_balance: z.coerce.number().min(-1_000_000).max(10_000_000) }).safeParse(await readBody(c));
  if (!p.success) return validationFailed(c, zodErrors(p.error));
  await c.get("db").query(
    "insert into app.settings (key, value) values ('driver_min_wallet_balance', $1::jsonb) on conflict (key) do update set value = excluded.value",
    [JSON.stringify(p.data.driver_min_wallet_balance)]);
  await audit(c, "wallet_settings", "driver_min_wallet_balance", { value: p.data.driver_min_wallet_balance });
  return c.json({ message: "Saved" });
});

/** Manual credit or debit for a driver (cash handed in, a correction, a goodwill credit). Always needs a reason. */
adminWalletRoutes.post("/admin/driver-wallets/:id/adjust", ...guard("driver_wallet edit"), async (c) => {
  const id = idParam(c); if (!id) return c.json({ message: "Not found" }, 404);
  const p = z.object({
    direction: z.enum(["credit", "debit"]), amount: z.coerce.number().positive().max(10_000_000),
    reason: z.string().trim().min(3).max(200),
  }).safeParse(await readBody(c));
  if (!p.success) return validationFailed(c, zodErrors(p.error));
  const amount = toMoney(p.data.amount);
  if (!amount) return validationFailed(c, { amount: ["Enter a valid amount."] });
  const db = c.get("db");
  const driver = (await db.query("select 1 from app.users where id = $1 and 'driver' = any(roles) and deleted_at is null", [id])).rowCount;
  if (!driver) return c.json({ message: "Driver not found", status: 404 }, 404);
  try {
    await db.query("begin");
    const r = await postToWallet(db, {
      userId: id, direction: p.data.direction, amount, kind: "adjustment", wallet: "driver", allowNegative: true,
      idempotencyKey: `adjust:${crypto.randomUUID()}`, description: p.data.reason, meta: { by_admin: c.get("user").id },
    });
    await audit(c, "driver_wallet_adjust", String(id), { direction: p.data.direction, amount, reason: p.data.reason });
    await db.query("commit");
    return c.json({ message: "Done", balance: Number(r.balance) });
  } catch (e) {
    await db.query("rollback").catch(() => undefined);
    throw e;
  }
});
