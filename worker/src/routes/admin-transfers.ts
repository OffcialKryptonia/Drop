import { Hono } from "hono";
import type { AppEnv } from "../env";
import { guard } from "../lib/permissions";
import { readBody, validationFailed } from "../lib/legacy";
import { getTransferSettings } from "./wallet-transfer";

export const adminTransferRoutes = new Hono<AppEnv>();

adminTransferRoutes.get("/admin/wallet-transfers", ...guard("wallet_transfer list"), async (c) => {
  const db = c.get("db");
  const page = Math.max(Number(c.req.query("page")) || 1, 1);
  const total = (await db.query("select count(*)::int n from app.wallet_transfers")).rows[0].n;
  const rows = (await db.query(
    `select t.id, t.amount, t.note, t.created_at, s.username as sender, r.username as recipient
       from app.wallet_transfers t join app.users s on s.id = t.sender_id join app.users r on r.id = t.recipient_id
      order by t.id desc limit 30 offset $1`, [(page - 1) * 30])).rows;
  return c.json({ settings: await getTransferSettings(db), data: rows, pagination: { page, total_pages: Math.max(Math.ceil(total / 30), 1), total } });
});

adminTransferRoutes.put("/admin/wallet-transfers/settings", ...guard("wallet_transfer edit"), async (c) => {
  const b = await readBody(c);
  const min = Number(b.min), max = Number(b.max), daily = Number(b.daily_limit);
  if (![min, max, daily].every((v) => Number.isFinite(v) && v > 0)) return validationFailed(c, { min: ["Enter amounts above zero."] });
  if (min > max || max > daily) return validationFailed(c, { max: ["Smallest must not exceed largest, and largest must not exceed the daily limit."] });
  const value = { enabled: b.enabled !== false, min, max, daily_limit: daily };
  await c.get("db").query("insert into app.settings (key, value) values ('wallet_transfer', $1::jsonb) on conflict (key) do update set value = excluded.value", [JSON.stringify(value)]);
  return c.json({ message: "Saved" });
});
