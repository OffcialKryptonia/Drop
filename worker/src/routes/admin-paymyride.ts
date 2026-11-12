import { Hono } from "hono";
import type { AppEnv } from "../env";
import { guard } from "../lib/permissions";
import { readBody, validationFailed } from "../lib/legacy";
import { getPayLinkSettings } from "../lib/paymyride";

export const adminPayMyRideRoutes = new Hono<AppEnv>();

adminPayMyRideRoutes.get("/admin/paymyride", ...guard("paymyride list"), async (c) => {
  const db = c.get("db");
  const page = Math.max(Number(c.req.query("page")) || 1, 1);
  const total = (await db.query("select count(*)::int n from app.ride_pay_links")).rows[0].n;
  const rows = (await db.query(
    `select l.id, l.amount, l.status, l.gateway, l.payer_name, l.paid_at, l.created_at, u.username as passenger
       from app.ride_pay_links l join app.users u on u.id = l.user_id
      order by l.id desc limit 30 offset $1`, [(page - 1) * 30])).rows;
  return c.json({ settings: await getPayLinkSettings(db), data: rows, pagination: { page, total_pages: Math.max(Math.ceil(total / 30), 1), total } });
});

adminPayMyRideRoutes.put("/admin/paymyride/settings", ...guard("paymyride edit"), async (c) => {
  const b = await readBody(c);
  const hours = Number(b.link_hours);
  if (!Number.isFinite(hours) || hours < 1 || hours > 72) return validationFailed(c, { link_hours: ["Enter hours between 1 and 72."] });
  await c.get("db").query("insert into app.settings (key, value) values ('paymyride', $1::jsonb) on conflict (key) do update set value = excluded.value", [JSON.stringify({ enabled: b.enabled !== false, link_hours: Math.round(hours) })]);
  return c.json({ message: "Saved" });
});
