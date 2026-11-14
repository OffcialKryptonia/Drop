import { Hono } from "hono";
import type { AppEnv } from "../env";
import { withDb } from "../db";
import { requireAuth } from "../auth/middleware";
import { readBody } from "../lib/legacy";
import { vehicleFromProfile } from "../lib/driver-vehicle";
import { getPayoutSettings } from "./payouts";
import { routeLine } from "../lib/routing";
import { iconKeyFor } from "./map-icons";

/** Small, fast endpoints the driver screens read: profile (referral code, vehicle), payouts overview, earnings. */
export const driverExtraRoutes = new Hono<AppEnv>();

const STATUS_TEXT: Record<string, string> = { pending: "Pending", paid: "Paid", declined: "Declined" };

/** Referral code, ride type and vehicle in one call. Works for any signed-in person who has a driver application. */
driverExtraRoutes.get("/driver/profile", withDb, requireAuth, async (c) => {
  const db = c.get("db");
  const me = c.get("user");
  const p = (await db.query(
    `select p.status, p.service_id, p.vehicle_make, p.vehicle_model, p.vehicle_year, p.vehicle_colour, p.vehicle_plate, s.name as service_name, s.category as service_category, s.map_icon_key
       from app.driver_profiles p left join app.services s on s.id = p.service_id where p.user_id = $1`, [me.id])).rows[0];
  const d = (await db.query("select car_model, car_color, car_plate_number, car_production_year from app.user_details where user_id = $1 limit 1", [me.id])).rows[0] ?? {};
  const v = vehicleFromProfile(p) ?? { car_model: null, car_color: null, car_plate_number: null, car_production_year: null };
  return c.json({
    referral_code: me.referral_code ?? null,
    service_name: p?.service_name ?? null,
    map_icon: iconKeyFor(p?.service_category, p?.map_icon_key),
    vehicle: {
      model: d.car_model || v.car_model || "",
      color: d.car_color || v.car_color || "",
      plate: d.car_plate_number || v.car_plate_number || "",
      year: d.car_production_year || v.car_production_year || "",
    },
  });
});

/** Everything the withdraw screen needs: balance, smallest payout, bank account and the history. */
driverExtraRoutes.get("/driver/payouts", withDb, requireAuth, async (c) => {
  const db = c.get("db");
  const me = c.get("user");
  const settings = await getPayoutSettings(db);
  const w = (await db.query("select balance, currency from app.wallets where user_id = $1 and kind = 'driver'", [me.id])).rows[0];
  const bank = (await db.query("select bank_name, account_number, account_holder_name from app.user_bank_accounts where user_id = $1", [me.id])).rows[0];
  const rows = (await db.query("select id, amount, currency, status, created_at from app.withdraw_requests where user_id = $1 order by id desc limit 30", [me.id])).rows;
  const pending = rows.some((r) => r.status === "pending");
  return c.json({
    enabled: settings.enabled,
    min_amount: settings.min_amount,
    balance: Number(w?.balance ?? 0),
    currency: String(w?.currency ?? "NGN").trim(),
    has_pending: pending,
    bank: bank?.account_number ? { bank_name: bank.bank_name, account_number: bank.account_number, account_name: bank.account_holder_name } : null,
    history: rows.map((r) => ({ id: Number(r.id), amount: Number(r.amount), currency: String(r.currency).trim(), status: r.status, status_text: STATUS_TEXT[r.status] ?? r.status, created_at: r.created_at })),
  });
});

const day = (d: Date) => d.toISOString().slice(0, 10);
const DAYS = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];

/**
 * Earnings for the driver's Earnings screen (Today / Weekly / Report), same field names the screen already reads.
 * A trip's earning is its fare minus DROP's commission, for completed trips only. Days are Lagos days.
 */
driverExtraRoutes.post("/earning-list", withDb, requireAuth, async (c) => {
  const db = c.get("db");
  const me = c.get("user");
  const b = await readBody(c);
  const type = String(b.type ?? "today");
  const tz = "Africa/Lagos";

  const sum = async (from: string, to: string) => (await db.query(
    `select count(*)::int as rides,
            coalesce(sum(fare - coalesce(commission, 0)), 0)::float8 as earned,
            coalesce(sum(case when coalesce(paid_with, payment_method) = 'cash' then fare else 0 end), 0)::float8 as cash,
            coalesce(sum(case when coalesce(paid_with, payment_method) = 'wallet' then fare else 0 end), 0)::float8 as wallet,
            coalesce(sum(case when coalesce(paid_with, payment_method) in ('card', 'virtual_account') then fare else 0 end), 0)::float8 as card
       from app.ride_requests
      where driver_id = $1 and status = 'completed'
        and (completed_at at time zone $4)::date between $2::date and $3::date`, [me.id, from, to, tz])).rows[0];

  const today = (await db.query("select (now() at time zone $1)::date::text as d", [tz])).rows[0].d as string;

  if (type === "report") {
    const from = /^\d{4}-\d{2}-\d{2}$/.test(String(b.from_date)) ? String(b.from_date) : today;
    const to = /^\d{4}-\d{2}-\d{2}$/.test(String(b.to_date)) ? String(b.to_date) : today;
    const r = await sum(from, to);
    return c.json({ from_date: from, to_date: to, today_date: today, total_ride_count: r.rides, total_cash_ride: r.cash, total_wallet_ride: r.wallet, total_card_ride: r.card, total_earnings: r.earned });
  }

  if (type === "week") {
    const end = new Date(`${today}T00:00:00Z`);
    const start = new Date(end); start.setUTCDate(end.getUTCDate() - 6);
    const r = await sum(day(start), day(end));
    const perDay = (await db.query(
      `select (completed_at at time zone $4)::date::text as d, coalesce(sum(fare - coalesce(commission, 0)), 0)::float8 as earned
         from app.ride_requests
        where driver_id = $1 and status = 'completed' and (completed_at at time zone $4)::date between $2::date and $3::date
        group by 1`, [me.id, day(start), day(end), tz])).rows;
    const byDay = new Map(perDay.map((x) => [x.d as string, Number(x.earned)]));
    const week = Array.from({ length: 7 }, (_, i) => {
      const dt = new Date(start); dt.setUTCDate(start.getUTCDate() + i);
      return { date: day(dt), day: DAYS[dt.getUTCDay()], amount: byDay.get(day(dt)) ?? 0 };
    });
    return c.json({ from_date: day(start), to_date: day(end), today_date: today, total_ride_count: r.rides, total_cash_ride: r.cash, total_wallet_ride: r.wallet, total_card_ride: r.card, total_earnings: r.earned, week_report: week });
  }

  const r = await sum(today, today);
  return c.json({ today_date: today, today_earnings: r.earned, today_ride_request: r.rides, total_cash_ride: r.cash, total_wallet_ride: r.wallet, total_card_ride: r.card, total_earnings: r.earned, total_ride_count: r.rides });
});

/** Road line between two points, for the pickup → drop-off line on the map. Query: from=lat,lng&to=lat,lng */
driverExtraRoutes.get("/route/line", withDb, requireAuth, async (c) => {
  const pair = (v: string | undefined) => {
    const [lat, lng] = String(v ?? "").split(",").map(Number);
    return Number.isFinite(lat) && Number.isFinite(lng) && Math.abs(lat) <= 90 && Math.abs(lng) <= 180 ? { lat, lng } : null;
  };
  const a = pair(c.req.query("from"));
  const b = pair(c.req.query("to"));
  if (!a || !b) return c.json({ error: "validation_failed", message: "from and to must be lat,lng." }, 422);
  const r = await routeLine(c.env, a, b, c.get("db"));
  return c.json({ points: r.points, road: r.road });
});
