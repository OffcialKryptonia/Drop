import { Hono } from "hono";
import type { AppEnv } from "../env";
import { withDb } from "../db";
import { requireAuth, USER_COLUMNS } from "../auth/middleware";
import { UNIQUE_VIOLATION } from "../db";
import { MESSAGES, readBody, validationFailed } from "../lib/legacy";
import { serializeService, serializeUser } from "../serializers/user";

/**
 * Compatibility endpoints for the screens that still call the old (Mighty-era) API names.
 * Each one returns the exact shape the app parses, so a screen shows a normal empty
 * state ("nothing here yet") instead of the "Requested service is not available" error.
 * Real implementations replace these one by one as each feature is rebuilt.
 */
export const legacyRoutes = new Hono<AppEnv>();

// Lists must always be fresh: never let a client or proxy reuse an old answer.
legacyRoutes.use("*", async (c, next) => {
  await next();
  c.header("Cache-Control", "no-store");
});

const CURRENCY = { name: "Nigerian Naira", code: "NGN", symbol: "₦", position: "left" };

const emptyPage = (c: { req: { query: (k: string) => string | undefined } }) => ({
  data: [] as unknown[],
  pagination: { currentPage: Number(c.req.query("page")) || 1, per_page: 20, totalPages: 1, total_items: 0 },
});

/** App-wide settings: currency (₦) and the feature switches the apps read. */
const settings = async (c: any) =>
  c.json({
    app_seeting: {},
    ride_setting: [],
    Wallet_setting: [],
    currency_setting: CURRENCY,
    privacy_policy: null,
    terms_condition: null,
    reference_amount: "0",
    reference_type: "fixed",
    maxEarningPerMonth: "0",
  });
legacyRoutes.get("/admin-dashboard", settings);
legacyRoutes.get("/appsetting", settings);

/** Home-screen poll. The new ride flow uses /ride/current, so there is nothing legacy to return. */
legacyRoutes.get("/current-riderequest", withDb, requireAuth, (c) => {
  const me = c.get("user");
  return c.json({
    id: me.id, display_name: me.display_name ?? null, email: me.email ?? null, username: me.username ?? null,
    user_type: me.user_type, all_unread_count: 0, ride_has_bids: false,
    ride_request: null, on_ride_request: null, schedule_ride_request: [],
  });
});

/** Ride types, admin-managed. */
legacyRoutes.get("/service-list", withDb, requireAuth, async (c) => {
  const rows = (await c.get("db").query("select * from app.services where status and deleted_at is null order by sort_order, id")).rows;
  return c.json({ data: rows.map(serializeService) });
});

/** Lists that are empty until their feature is rebuilt. */
for (const path of [
  "/faq-list", "/coupon-list", "/notification-list", "/reward-list", "/reference-list",
  "/complaintcomment-list", "/managezone-list", "/additional-fees-list", "/airport-list",
  "/earning-list", "/withdrawrequest-list", "/coin-wallet-list", "/driver-rating-list",
  "/rider-rating-list", "/cancelReason-list", "/language-table-list", "/document-list",
  "/driver-document-list", "/driver-payout-document-list",
]) {
  legacyRoutes.get(path, withDb, requireAuth, (c) => c.json(emptyPage(c)));
  legacyRoutes.post(path, withDb, requireAuth, (c) => c.json(emptyPage(c)));
}

/** Nearby drivers for the map. Live matching happens through /ride/request, so this is empty. */
legacyRoutes.get("/near-by-driver", withDb, requireAuth, (c) => c.json({ data: [] }));

const text = (v: unknown, max: number): string | null => (typeof v === "string" && v.trim() ? v.trim().slice(0, max) : null);

/**
 * Profile update. Used after login to link the chat (Firebase) uid, to save the push id, and from the
 * edit-profile screen. Only the fields that arrive are changed; an empty value never wipes a field.
 */
legacyRoutes.post("/update-profile", withDb, requireAuth, async (c) => {
  const me = c.get("user");
  const db = c.get("db");
  const b = await readBody(c);
  const sets: string[] = [];
  const args: unknown[] = [me.id];
  const add = (col: string, value: unknown) => { if (value !== null && value !== undefined) { args.push(value); sets.push(`${col} = $${args.length}`); } };

  const first = text(b.first_name, 100), last = text(b.last_name, 100);
  add("first_name", first); add("last_name", last);
  if (first || last) add("display_name", `${first ?? me.first_name ?? ""} ${last ?? me.last_name ?? ""}`.trim());
  add("uid", text(b.uid, 200)); add("player_id", text(b.player_id, 200)); add("fcm_token", text(b.fcm_token, 1000));
  add("address", text(b.address, 500));
  const gender = text(b.gender, 10); if (gender && ["male", "female", "other"].includes(gender)) add("gender", gender);
  // The email is not changed here: it can reset the password, so changing it needs the password (POST /account/email).
  const phone = text(b.contact_number, 30)?.replace(/\D/g, "").replace(/^0+/, "");
  if (phone && phone !== String(me.contact_number ?? "").replace(/\D/g, "").replace(/^0+/, "")) {
    if (phone.length < 6 || phone.length > 13) return validationFailed(c, { contact_number: ["Enter a valid phone number."] });
    add("contact_number", phone);
  }
  try {
    if (sets.length) await db.query(`update app.users set ${sets.join(", ")} where id = $1`, args);
  } catch (err) {
    const e = err as { code?: string; constraint?: string };
    if (e.code === UNIQUE_VIOLATION) return validationFailed(c, e.constraint?.includes("phone") ? { contact_number: ["This phone number already has an account."] } : { email: ["The email has already been taken."] });
    throw err;
  }
  const row = (await db.query(`select ${USER_COLUMNS} from app.users u where u.id = $1`, [me.id])).rows[0];
  return c.json({ message: "Profile has been updated successfully", data: { ...serializeUser(row), profile_image: null } });
});

/** The app tells us its push id (and sometimes a status). Accepts the push fields only. */
legacyRoutes.post("/update-user-status", withDb, requireAuth, async (c) => {
  const me = c.get("user");
  const db = c.get("db");
  const b = await readBody(c);
  await db.query(
    "update app.users set player_id = coalesce($2, player_id), fcm_token = coalesce($3, fcm_token), last_actived_at = now() where id = $1",
    [me.id, text(b.player_id, 200), text(b.fcm_token, 1000)],
  );
  const row = (await db.query(`select ${USER_COLUMNS} from app.users u where u.id = $1`, [me.id])).rows[0];
  return c.json({ message: "Status updated", data: { ...serializeUser(row), profile_image: null } });
});

const iso = (v: unknown) => (v instanceof Date ? v.toISOString() : v == null ? null : String(v));

/** Ride history for the Rides screen (Completed / Cancelled tabs). */
legacyRoutes.get("/riderequest-list", withDb, requireAuth, async (c) => {
  const me = c.get("user");
  const db = c.get("db");
  const page = Math.max(Number(c.req.query("page")) || 1, 1);
  const perPage = 20;
  const status = c.req.query("status");
  const statuses = status === "completed" ? ["completed"] : status === "cancelled" ? ["cancelled", "expired"] : ["completed", "cancelled", "expired"];
  const total = (await db.query("select count(*)::int n from app.ride_requests where rider_id = $1 and status = any($2)", [me.id, statuses])).rows[0].n;
  const rows = (await db.query(
    `select r.*, du.first_name as df, du.last_name as dl from app.ride_requests r
       left join app.users du on du.id = r.driver_id
      where r.rider_id = $1 and r.status = any($2) order by r.id desc limit $3 offset $4`,
    [me.id, statuses, perPage, (page - 1) * perPage])).rows;
  const name = me.display_name ?? `${me.first_name ?? ""} ${me.last_name ?? ""}`.trim();
  return c.json({
    data: rows.map((r) => ({
      id: Number(r.id), rider_id: Number(me.id), rider_name: name, service_id: Number(r.service_id),
      driver_id: r.driver_id == null ? null : Number(r.driver_id),
      driver_name: r.driver_id ? [r.df, r.dl].filter(Boolean).join(" ") : null,
      datetime: iso(r.created_at), start_time: iso(r.created_at), end_time: iso(r.completed_at),
      start_address: r.pickup_address, end_address: r.dropoff_address,
      start_latitude: String(r.pickup_lat), start_longitude: String(r.pickup_lng),
      end_latitude: String(r.dropoff_lat), end_longitude: String(r.dropoff_lng),
      distance: Number(r.distance), distance_unit: r.distance_unit, duration: Number(r.duration_minutes),
      total_amount: Number(r.fare), subtotal: Number(r.fare), estimated_price: Number(r.fare),
      cancelation_charges: Number(r.cancellation_fee ?? 0),
      status: r.status === "expired" ? "canceled" : r.status === "cancelled" ? "canceled" : r.status,
      reason: r.cancel_reason ?? null, is_schedule: 0, ride_has_bids: 0,
    })),
    pagination: { currentPage: page, per_page: perPage, totalPages: Math.max(Math.ceil(total / perPage), 1), total_items: total },
  });
});

/** Emergency contacts. */
const sosPage = async (c: any, page = 1) => {
  const rows = (await c.get("db").query("select * from app.sos_contacts where user_id = $1 order by id", [c.get("user").id])).rows;
  return {
    data: rows.map((r: any) => ({ id: Number(r.id), added_by: Number(c.get("user").id), title: r.title, contact_number: r.contact_number, region_id: null, status: 1, created_at: iso(r.created_at), updated_at: iso(r.created_at) })),
    pagination: { currentPage: page, per_page: 50, totalPages: 1, total_items: rows.length },
  };
};
legacyRoutes.get("/sos-list", withDb, requireAuth, async (c) => c.json(await sosPage(c, Number(c.req.query("page")) || 1)));
legacyRoutes.post("/save-sos", withDb, requireAuth, async (c) => {
  const b = await readBody(c);
  const title = text(b.title, 100);
  const number = text(b.contact_number, 30);
  if (!title) return validationFailed(c, { title: ["Enter a name for this contact."] });
  if (!number || number.replace(/\D/g, "").length < 7) return validationFailed(c, { contact_number: ["Enter a valid phone number."] });
  const db = c.get("db");
  const n = (await db.query("select count(*)::int n from app.sos_contacts where user_id = $1", [c.get("user").id])).rows[0].n;
  if (n >= 5) return validationFailed(c, { contact_number: ["You can save up to 5 emergency contacts."] });
  await db.query("insert into app.sos_contacts (user_id, title, contact_number) values ($1, $2, $3)", [c.get("user").id, title, number]);
  return c.json({ message: "Emergency contact added" });
});
legacyRoutes.post("/sos-delete/:id", withDb, requireAuth, async (c) => {
  await c.get("db").query("delete from app.sos_contacts where id = $1 and user_id = $2", [c.req.param("id"), c.get("user").id]);
  return c.json(await sosPage(c));
});
