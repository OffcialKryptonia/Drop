import { Hono, type Context } from "hono";
import { z } from "zod";
import type { AppEnv } from "../env";
import { withDb } from "../db";
import { requireAuth } from "../auth/middleware";
import { guard, audit } from "../lib/permissions";
import { readBody, validationFailed } from "../lib/legacy";
import { requireApprovedDriver } from "../lib/roles";
import { closeExtra, reverseExtra, EXTRA_KINDS, extraView, extrasSettings, kindLabel, payExtra, proposeExtra } from "../lib/extras";
import { currencyInfo } from "../lib/currency";
import { pushLater, sendPush } from "../lib/push";

export const rideExtraRoutes = new Hono<AppEnv>();
type C = Context<AppEnv>;

const driverMode = async (c: C, next: () => Promise<void>) => {
  if (c.get("user").active_mode !== "driver") return c.json({ status: false, code: "not_in_driver_mode", message: "Switch to Driver mode first." }, 409);
  await next();
};
const driverMw = [withDb, requireAuth, requireApprovedDriver, driverMode] as const;
const riderMw = [withDb, requireAuth] as const;

const money = (n: unknown, currency: unknown) => `${currencyInfo(String(currency ?? "NGN").trim()).symbol}${Number(n).toLocaleString("en-NG", { maximumFractionDigits: 2 })}`;
const rideIdOf = (c: C) => {
  const id = Number(c.req.param("id"));
  return Number.isInteger(id) && id > 0 ? id : null;
};

// ---- Driver ----

const proposeSchema = z.object({
  kind: z.enum(EXTRA_KINDS, { error: "Choose what the charge is for." }),
  amount: z.coerce.number({ error: "Enter the amount." }).positive({ error: "Enter the amount." }).max(100_000_000),
  note: z.string().trim().max(120).optional(),
});

/** The driver adds an extra charge (toll, parking, waiting) after accepting, before arriving at the pickup. The passenger is asked to approve. */
rideExtraRoutes.post("/driver/rides/:id/extras", ...driverMw, async (c) => {
  const rideId = rideIdOf(c);
  if (!rideId) return c.json({ status: false, message: "Trip not found." }, 404);
  const p = proposeSchema.safeParse(await readBody(c));
  if (!p.success) return validationFailed(c, { extra: [p.error.issues[0].message] });
  const db = c.get("db");
  const r = await proposeExtra(db, { rideId, driverId: c.get("user").id, kind: p.data.kind, amount: Math.round(p.data.amount * 100) / 100, note: p.data.note });
  if (!r.ok) return c.json({ status: false, code: r.code, message: r.message, remaining: r.remaining ?? null }, 422);
  const e = r.extra;
  pushLater(c, sendPush(db, c.env, [r.rider_id], {
    title: "Extra charge from your driver",
    body: `${kindLabel(e.kind)} · ${money(e.amount, e.currency)}. Open DROP to approve or decline.`,
    data: { type: "extra_charge", extra_id: String(e.id), ride_id: String(rideId) },
  }));
  return c.json({ status: true, data: extraView(e) }, 201);
});

/** Extras on one of the driver's trips, plus how much more they may still add. */
rideExtraRoutes.get("/driver/rides/:id/extras", ...driverMw, async (c) => {
  const rideId = rideIdOf(c);
  if (!rideId) return c.json({ status: false, message: "Trip not found." }, 404);
  const db = c.get("db");
  const ride = (await db.query("select fare, status from app.ride_requests where id = $1 and driver_id = $2", [rideId, c.get("user").id])).rows[0];
  if (!ride) return c.json({ status: false, message: "Trip not found." }, 404);
  const s = await extrasSettings(db);
  const rows = (await db.query("select * from app.ride_extras where ride_request_id = $1 order by id", [rideId])).rows;
  const used = rows.filter((x) => x.status === "pending" || x.status === "paid").reduce((a, x) => a + Number(x.amount), 0);
  const remaining = Math.max(0, Math.round((Number(ride.fare) * s.max_percent) / 100 * 100) / 100 - used);
  const open = s.enabled && ride.status === "accepted";
  return c.json({ status: true, data: rows.map(extraView), can_add: !!open && remaining > 0 && !rows.some((x) => x.status === "pending"), remaining: Math.round(remaining * 100) / 100, window_minutes: s.window_minutes });
});

rideExtraRoutes.post("/driver/extras/:id/cancel", ...driverMw, async (c) => {
  const id = rideIdOf(c);
  const row = id ? await closeExtra(c.get("db"), id, { driverId: c.get("user").id }, "cancelled") : null;
  return row ? c.json({ status: true }) : c.json({ status: false, message: "This extra charge can no longer be withdrawn." }, 409);
});

// ---- Passenger ----

/** Extra charges waiting for the passenger's answer, with their wallet balance. */
rideExtraRoutes.get("/ride/extras/pending", ...riderMw, async (c) => {
  const db = c.get("db");
  const me = c.get("user");
  const rows = (await db.query(
    `select x.*, du.first_name as driver_first_name, r.pickup_address, r.dropoff_address
       from app.ride_extras x join app.ride_requests r on r.id = x.ride_request_id join app.users du on du.id = x.driver_id
      where x.rider_id = $1 and x.status = 'pending' and x.expires_at > now() order by x.id`, [me.id])).rows;
  const bal = Number((await db.query("select balance from app.wallets where user_id = $1 and kind = 'rider'", [me.id])).rows[0]?.balance ?? 0);
  return c.json({
    status: true,
    wallet_balance: bal,
    data: rows.map((x) => ({ ...extraView(x), driver_first_name: x.driver_first_name ?? null, pickup: x.pickup_address ?? null, dropoff: x.dropoff_address ?? null })),
  });
});

rideExtraRoutes.post("/ride/extras/:id/pay", ...riderMw, async (c) => {
  const id = rideIdOf(c);
  const p = z.object({ method: z.enum(["wallet", "cash"], { error: "Choose wallet or cash." }) }).safeParse(await readBody(c));
  if (!id || !p.success) return validationFailed(c, { method: ["Choose wallet or cash."] });
  const db = c.get("db");
  const r = await payExtra(db, id, c.get("user").id, p.data.method);
  if (!r.ok) return c.json({ status: false, code: r.code, message: r.message }, r.code === "not_found" ? 404 : 422);
  const e = r.extra;
  pushLater(c, sendPush(db, c.env, [Number(e.driver_id)], {
    title: e.paid_with === "wallet" ? "Extra charge paid" : "Collect cash for the extra charge",
    body: e.paid_with === "wallet" ? `${money(e.amount, e.currency)} was added to your wallet.` : `The passenger will pay ${money(e.amount, e.currency)} in cash.`,
    data: { type: "extra_charge_paid", extra_id: String(e.id), ride_id: String(e.ride_request_id) },
  }));
  return c.json({ status: true, data: extraView(e) });
});

rideExtraRoutes.post("/ride/extras/:id/decline", ...riderMw, async (c) => {
  const id = rideIdOf(c);
  const db = c.get("db");
  const row = id ? await closeExtra(db, id, { riderId: c.get("user").id }, "declined") : null;
  if (!row) return c.json({ status: false, message: "This extra charge has already been answered." }, 409);
  pushLater(c, sendPush(db, c.env, [Number(row.driver_id)], {
    title: "Extra charge declined", body: `The passenger declined the ${kindLabel(row.kind).toLowerCase()} of ${money(row.amount, row.currency)}.`,
    data: { type: "extra_charge_declined", extra_id: String(row.id), ride_id: String(row.ride_request_id) },
  }));
  return c.json({ status: true });
});

// ---- Admin ----

rideExtraRoutes.get("/admin/extras-settings", ...guard("service_option list"), async (c) => c.json({ data: await extrasSettings(c.get("db")) }));
rideExtraRoutes.put("/admin/extras-settings", ...guard("service_option edit"), async (c) => {
  const p = z.object({
    enabled: z.boolean(),
    max_percent: z.coerce.number().min(0, "Use 0 to 100.").max(100, "Use 0 to 100."),
    commission_percent: z.coerce.number().min(0, "Use 0 to 100.").max(100, "Use 0 to 100."),
    window_minutes: z.coerce.number().int().min(1, "Use 1 to 60 minutes.").max(60, "Use 1 to 60 minutes."),
  }).safeParse(await readBody(c));
  if (!p.success) return validationFailed(c, { extras: [p.error.issues[0].message] });
  await c.get("db").query("insert into app.settings (key, value) values ('extras', $1::jsonb) on conflict (key) do update set value = excluded.value", [JSON.stringify(p.data)]);
  await audit(c, "extras_settings.update", "extras", p.data);
  return c.json({ status: true, data: p.data });
});

/** Admin: every extra charge, newest first, filtered by status. */
rideExtraRoutes.get("/admin/extras", ...guard("ride_extra list"), async (c) => {
  const db = c.get("db");
  const status = ["pending", "paid", "declined", "expired", "cancelled"].includes(String(c.req.query("status"))) ? String(c.req.query("status")) : null;
  const page = Math.max(1, Number(c.req.query("page")) || 1);
  const per = 20;
  const where = status ? "where x.status = $1" : "where $1::text is null";
  const total = Number((await db.query(`select count(*) from app.ride_extras x ${where}`, [status])).rows[0].count);
  const rows = (await db.query(
    `select x.*, d.display_name as driver_name, p.display_name as passenger_name
       from app.ride_extras x join app.users d on d.id = x.driver_id join app.users p on p.id = x.rider_id
       ${where} order by x.id desc limit ${per} offset ${(page - 1) * per}`, [status])).rows;
  return c.json({
    data: rows.map((x) => ({ ...extraView(x), driver_name: x.driver_name, passenger_name: x.passenger_name })),
    pagination: { page, total, total_pages: Math.max(1, Math.ceil(total / per)) },
  });
});

/** Admin: cancel a pending extra, or refund a paid one (wallet money goes back to the passenger and is taken from the driver). */
rideExtraRoutes.post("/admin/extras/:id/refund", ...guard("ride_extra edit"), async (c) => {
  const id = rideIdOf(c);
  if (!id) return c.json({ status: false, message: "Extra charge not found." }, 404);
  const db = c.get("db");
  await db.query("begin");
  try {
    const e = (await db.query("select * from app.ride_extras where id = $1 for update", [id])).rows[0];
    if (!e) { await db.query("rollback"); return c.json({ status: false, message: "Extra charge not found." }, 404); }
    if (e.status !== "pending" && e.status !== "paid") { await db.query("rollback"); return c.json({ status: false, message: "Only a pending or paid extra charge can be cancelled or refunded." }, 409); }
    await reverseExtra(db, e);
    await db.query("commit");
    await audit(c, "extra.refund", `extra:${id}`, { status: e.status, paid_with: e.paid_with, amount: Number(e.amount) });
    pushLater(c, sendPush(db, c.env, [Number(e.rider_id)], {
      title: e.status === "paid" && e.paid_with === "wallet" ? "Extra charge refunded" : "Extra charge cancelled",
      body: `${kindLabel(e.kind)} · ${money(e.amount, e.currency)}`, data: { type: "extra_charge_refunded", extra_id: String(id), ride_id: String(e.ride_request_id) },
    }));
    return c.json({ status: true, message: e.status === "paid" && e.paid_with === "wallet" ? "Refunded to the passenger's wallet." : "Extra charge cancelled." });
  } catch (err) { await db.query("rollback").catch(() => {}); throw err; }
});
