import { Hono, type Context } from "hono";
import { z } from "zod";
import type { AppEnv } from "../env";
import { withDb } from "../db";
import { requireAuth } from "../auth/middleware";
import { guard, audit } from "../lib/permissions";
import { readBody, validationFailed } from "../lib/legacy";
import { requireApprovedDriver } from "../lib/roles";
import { closeExtra, EXTRA_KINDS, extraView, extrasSettings, kindLabel, payExtra, proposeExtra } from "../lib/extras";
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

/** The driver adds an extra charge (toll, parking, waiting) to a finished trip. The passenger is asked to approve. */
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
  const ride = (await db.query("select fare, status, completed_at from app.ride_requests where id = $1 and driver_id = $2", [rideId, c.get("user").id])).rows[0];
  if (!ride) return c.json({ status: false, message: "Trip not found." }, 404);
  const s = await extrasSettings(db);
  const rows = (await db.query("select * from app.ride_extras where ride_request_id = $1 order by id", [rideId])).rows;
  const used = rows.filter((x) => x.status === "pending" || x.status === "paid").reduce((a, x) => a + Number(x.amount), 0);
  const remaining = Math.max(0, Math.round((Number(ride.fare) * s.max_percent) / 100 * 100) / 100 - used);
  const open = s.enabled && ride.status === "completed" && ride.completed_at && Date.now() - new Date(ride.completed_at as string).getTime() <= s.window_minutes * 60000;
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
    window_minutes: z.coerce.number().int().min(5, "Use 5 to 240 minutes.").max(240, "Use 5 to 240 minutes."),
  }).safeParse(await readBody(c));
  if (!p.success) return validationFailed(c, { extras: [p.error.issues[0].message] });
  await c.get("db").query("insert into app.settings (key, value) values ('extras', $1::jsonb) on conflict (key) do update set value = excluded.value", [JSON.stringify(p.data)]);
  await audit(c, "extras_settings.update", "extras", p.data);
  return c.json({ status: true, data: p.data });
});
