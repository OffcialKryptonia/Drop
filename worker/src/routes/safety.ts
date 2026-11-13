import { Hono } from "hono";
import type { Context } from "hono";
import type { Client } from "pg";
import type { AppEnv } from "../env";
import { withDb } from "../db";
import { requireAuth } from "../auth/middleware";
import { audit, guard } from "../lib/permissions";
import { readBody, validationFailed } from "../lib/legacy";
import { sendEmail } from "../lib/email";

/** SOS alerts and complaints: the app side (rider and driver) and the admin side. */
export const safetyRoutes = new Hono<AppEnv>();
export const adminSafetyRoutes = new Hono<AppEnv>();

const txt = (v: unknown, max: number) => (typeof v === "string" && v.trim() ? v.trim().slice(0, max) : null);
const coordOrNull = (v: unknown, lim: number) => { if (v === null || v === undefined || v === "") return null; const n = Number(v); return Number.isFinite(n) && Math.abs(n) <= lim ? n : null; };
const esc = (s: unknown) => String(s ?? "").replace(/[&<>"]/g, (ch) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[ch] as string));
const iso = (v: unknown) => (v instanceof Date ? v.toISOString() : v == null ? null : String(v));
type Person = { display_name?: unknown; first_name?: unknown; last_name?: unknown; username?: unknown; country_code?: unknown; contact_number?: unknown };
const fullName = (u: Person | undefined) => String(u?.display_name || [u?.first_name, u?.last_name].filter(Boolean).join(" ") || u?.username || "");
const phoneOf = (u: Person | undefined) => (u?.contact_number ? `+${String(u.country_code ?? "").replace(/\D/g, "")}${String(u.contact_number).replace(/^0+/, "")}` : "");

// ---------------------------------------------------------------- SOS

/** Creates the alert (one per minute, so a nervous double-tap sends one) and emails the admins. */
async function raiseSos(c: Context<AppEnv>, b: Record<string, unknown>) {
  const db = c.get("db");
  const me = c.get("user");
  const dup = (await db.query("select id from app.sos_alerts where user_id = $1 and status = 'open' and created_at > now() - interval '60 seconds' order by id desc limit 1", [me.id])).rows[0];
  if (dup) return c.json({ status: true, message: "Your alert has been sent. Help is being arranged.", id: Number(dup.id) });

  const rideId = /^\d{1,15}$/.test(String(b.ride_request_id ?? "")) ? Number(b.ride_request_id) : null;
  const ride = rideId
    ? (await db.query("select r.id, r.status, r.pickup_address, r.dropoff_address, r.rider_id, r.driver_id from app.ride_requests r where r.id = $1 and (r.rider_id = $2 or r.driver_id = $2)", [rideId, me.id])).rows[0]
    : undefined;
  const role = ride ? (Number(ride.driver_id) === Number(me.id) ? "driver" : "rider") : me.active_mode === "driver" ? "driver" : "rider";
  const otherId = ride ? (role === "driver" ? ride.rider_id : ride.driver_id) : null;
  const other = otherId ? (await db.query("select first_name, last_name, display_name, username, country_code, contact_number from app.users where id = $1", [otherId])).rows[0] : undefined;
  const vehicle = ride?.driver_id ? (await db.query("select vehicle_make, vehicle_model, vehicle_colour, vehicle_plate from app.driver_profiles where user_id = $1", [ride.driver_id])).rows[0] : undefined;
  const context = {
    person: { name: fullName(me as Person), phone: phoneOf(me as Person) },
    other_party: other ? { name: fullName(other), phone: phoneOf(other) } : null,
    ride: ride ? { id: Number(ride.id), status: ride.status, pickup: ride.pickup_address, dropoff: ride.dropoff_address } : null,
    vehicle: vehicle ? { description: [vehicle.vehicle_colour, vehicle.vehicle_make, vehicle.vehicle_model].filter(Boolean).join(" "), plate: vehicle.vehicle_plate } : null,
  };
  const lat = coordOrNull(b.latitude, 90), lng = coordOrNull(b.longitude, 180);
  const id = Number((await db.query(
    "insert into app.sos_alerts (user_id, role, ride_request_id, latitude, longitude, message, context) values ($1,$2,$3,$4,$5,$6,$7::jsonb) returning id",
    [me.id, role, ride ? Number(ride.id) : null, lat, lng, txt(b.message, 500), JSON.stringify(context)])).rows[0].id);

  // Tell the admins by email right away (best effort: the alert is already saved and shows in the admin panel).
  const work = (async () => {
    const to = await adminEmails(db);
    const map = lat != null && lng != null ? `https://www.google.com/maps?q=${lat},${lng}` : "";
    const html = `<h2>SOS alert #${id}</h2><p><b>${esc(context.person.name)}</b> (${role}) ${esc(context.person.phone)} needs help.</p>`
      + (ride ? `<p>Trip #${ride.id} (${esc(ride.status)}): ${esc(ride.pickup_address)} to ${esc(ride.dropoff_address)}</p>` : "")
      + (other ? `<p>${role === "driver" ? "Passenger" : "Driver"}: ${esc(context.other_party?.name)} ${esc(context.other_party?.phone)}</p>` : "")
      + (context.vehicle ? `<p>Vehicle: ${esc(context.vehicle.description)} ${esc(context.vehicle.plate)}</p>` : "")
      + (map ? `<p><a href="${map}">Open location on the map</a></p>` : "<p>No location was shared.</p>")
      + `<p>Handle it in Admin, Safety, SOS alerts.</p>`;
    await Promise.all(to.map((email) => sendEmail(db, c.env.SETTINGS_ENCRYPTION_KEY, { to: email, subject: `SOS alert #${id}: ${context.person.name}`, html })));
  })().catch((e) => console.error("sos email failed", (e as Error).message));
  try { c.executionCtx.waitUntil(work); } catch { await work; }
  return c.json({ status: true, message: "Your alert has been sent. Help is being arranged.", id });
}

async function adminEmails(db: Client): Promise<string[]> {
  const s = (await db.query("select value from app.settings where key = 'safety'")).rows[0]?.value ?? {};
  const listed = String(s.notify_emails ?? "").split(/[,;\s]+/).filter((e) => /^\S+@\S+\.\S+$/.test(e));
  if (listed.length) return listed.slice(0, 5);
  return (await db.query("select email from app.users where user_type = 'admin' and deleted_at is null and email is not null and status = 'active' order by id limit 5")).rows.map((r) => String(r.email));
}

safetyRoutes.post("/sos/alert", withDb, requireAuth, async (c) => raiseSos(c, await readBody(c)));
// The older screens call this name.
safetyRoutes.post("/admin-sos-notify", withDb, requireAuth, async (c) => raiseSos(c, await readBody(c)));

// ---------------------------------------------------------------- Complaints (app)

const COMPLAINT_STATUS_TEXT: Record<string, string> = { pending: "Received", investigating: "Being looked into", resolved: "Resolved" };
const complaintOut = (r: Record<string, unknown>) => ({
  id: Number(r.id), subject: r.subject, description: r.description, status: r.status, status_text: COMPLAINT_STATUS_TEXT[String(r.status)] ?? r.status,
  ride_request_id: r.ride_request_id == null ? null : Number(r.ride_request_id), created_at: iso(r.created_at), updated_at: iso(r.updated_at),
});

async function createComplaint(c: Context<AppEnv>, b: Record<string, unknown>) {
  const db = c.get("db");
  const me = c.get("user");
  const subject = txt(b.subject, 150), description = txt(b.description, 3000);
  if (!subject) return validationFailed(c, { subject: ["Enter a short subject."] });
  if (!description) return validationFailed(c, { description: ["Tell us what happened."] });
  const rideId = /^\d{1,15}$/.test(String(b.ride_request_id ?? "")) ? Number(b.ride_request_id) : null;
  const ride = rideId ? (await db.query("select id from app.ride_requests where id = $1 and (rider_id = $2 or driver_id = $2)", [rideId, me.id])).rows[0] : undefined;
  const recent = (await db.query("select count(*)::int n from app.complaints where user_id = $1 and created_at > now() - interval '1 hour'", [me.id])).rows[0].n;
  if (recent >= 5) return c.json({ status: false, message: "You have sent several complaints in the last hour. Please wait a little before sending another." }, 429);
  const row = (await db.query(
    "insert into app.complaints (user_id, role, ride_request_id, subject, description) values ($1,$2,$3,$4,$5) returning *",
    [me.id, me.active_mode === "driver" ? "driver" : "rider", ride ? Number(ride.id) : null, subject, description])).rows[0];
  return c.json({ status: true, message: "Your complaint has been received. We will reply here.", data: complaintOut(row) });
}

safetyRoutes.post("/complaints", withDb, requireAuth, async (c) => createComplaint(c, await readBody(c)));
// Older screens save through this name.
safetyRoutes.post("/save-complaint", withDb, requireAuth, async (c) => createComplaint(c, await readBody(c)));

safetyRoutes.get("/complaints", withDb, requireAuth, async (c) => {
  const rows = (await c.get("db").query("select * from app.complaints where user_id = $1 order by id desc limit 50", [c.get("user").id])).rows;
  return c.json({ data: rows.map(complaintOut) });
});

const commentOut = (m: Record<string, unknown>) => ({ id: Number(m.id), added_by: m.added_by, comment: m.comment, created_at: iso(m.created_at) });

safetyRoutes.get("/complaints/:id", withDb, requireAuth, async (c) => {
  const db = c.get("db");
  const id = Number(c.req.param("id"));
  if (!Number.isInteger(id)) return c.json({ message: "Complaint not found." }, 404);
  const r = (await db.query("select * from app.complaints where id = $1 and user_id = $2", [id, c.get("user").id])).rows[0];
  if (!r) return c.json({ message: "Complaint not found." }, 404);
  const comments = (await db.query("select id, added_by, comment, created_at from app.complaint_comments where complaint_id = $1 order by id", [id])).rows;
  return c.json({ data: { ...complaintOut(r), comments: comments.map(commentOut) } });
});

safetyRoutes.post("/complaints/:id/comments", withDb, requireAuth, async (c) => {
  const db = c.get("db");
  const me = c.get("user");
  const id = Number(c.req.param("id"));
  const comment = txt((await readBody(c)).comment, 2000);
  if (!comment) return validationFailed(c, { comment: ["Write your message."] });
  if (!Number.isInteger(id) || !(await db.query("select 1 from app.complaints where id = $1 and user_id = $2", [id, me.id])).rowCount) return c.json({ message: "Complaint not found." }, 404);
  await db.query("insert into app.complaint_comments (complaint_id, user_id, added_by, comment) values ($1,$2,'user',$3)", [id, me.id, comment]);
  await db.query("update app.complaints set updated_at = now(), status = case when status = 'resolved' then 'pending' else status end where id = $1", [id]);
  return c.json({ status: true });
});

// ---------------------------------------------------------------- Admin

adminSafetyRoutes.get("/admin/sos", ...guard("sos list"), async (c) => {
  const db = c.get("db");
  const status = ["open", "acknowledged", "resolved"].includes(String(c.req.query("status"))) ? String(c.req.query("status")) : "open";
  const page = Math.max(Number(c.req.query("page")) || 1, 1);
  const total = (await db.query("select count(*)::int n from app.sos_alerts where status = $1", [status])).rows[0].n;
  const rows = (await db.query("select * from app.sos_alerts where status = $1 order by id desc limit 30 offset $2", [status, (page - 1) * 30])).rows;
  const s = (await db.query("select value from app.settings where key = 'safety'")).rows[0]?.value ?? {};
  return c.json({
    settings: { notify_emails: String(s.notify_emails ?? "") },
    data: rows.map((r) => ({ ...r, id: Number(r.id), created_at: iso(r.created_at), handled_at: iso(r.handled_at), latitude: r.latitude == null ? null : Number(r.latitude), longitude: r.longitude == null ? null : Number(r.longitude) })),
    pagination: { page, total_pages: Math.max(Math.ceil(total / 30), 1), total },
  });
});

/** Cheap poll for the admin badge. */
adminSafetyRoutes.get("/admin/sos/open-count", ...guard("sos list"), async (c) =>
  c.json({ open: (await c.get("db").query("select count(*)::int n from app.sos_alerts where status = 'open'")).rows[0].n }));

adminSafetyRoutes.put("/admin/sos/settings", ...guard("sos edit"), async (c) => {
  const emails = String((await readBody(c)).notify_emails ?? "").trim().slice(0, 300);
  await c.get("db").query("insert into app.settings (key, value) values ('safety', $1::jsonb) on conflict (key) do update set value = app.settings.value || excluded.value", [JSON.stringify({ notify_emails: emails })]);
  return c.json({ message: "Saved" });
});

adminSafetyRoutes.put("/admin/sos/:id", ...guard("sos edit"), async (c) => {
  const id = Number(c.req.param("id"));
  const b = await readBody(c);
  const status = String(b.status);
  if (status !== "acknowledged" && status !== "resolved") return validationFailed(c, { status: ["Choose acknowledged or resolved."] });
  const r = await c.get("db").query("update app.sos_alerts set status = $2, admin_note = coalesce($3, admin_note), handled_by = $4, handled_at = now() where id = $1", [id, status, txt(b.note, 500), c.get("user").id]);
  if (!r.rowCount) return c.json({ message: "Not found" }, 404);
  await audit(c, "sos", String(id), { status });
  return c.json({ message: status === "resolved" ? "Marked as resolved" : "Marked as acknowledged" });
});

adminSafetyRoutes.get("/admin/complaints", ...guard("complaint list"), async (c) => {
  const db = c.get("db");
  const status = ["pending", "investigating", "resolved"].includes(String(c.req.query("status"))) ? String(c.req.query("status")) : "pending";
  const page = Math.max(Number(c.req.query("page")) || 1, 1);
  const total = (await db.query("select count(*)::int n from app.complaints where status = $1", [status])).rows[0].n;
  const rows = (await db.query(
    `select c.*, u.display_name, u.first_name, u.last_name, u.username from app.complaints c join app.users u on u.id = c.user_id
      where c.status = $1 order by c.id desc limit 30 offset $2`, [status, (page - 1) * 30])).rows;
  return c.json({ data: rows.map((r) => ({ ...complaintOut(r), role: r.role, person: fullName(r) })), pagination: { page, total_pages: Math.max(Math.ceil(total / 30), 1), total } });
});

adminSafetyRoutes.get("/admin/complaints/:id", ...guard("complaint list"), async (c) => {
  const db = c.get("db");
  const id = Number(c.req.param("id"));
  const r = (await db.query("select c.*, u.display_name, u.first_name, u.last_name, u.username, u.country_code, u.contact_number from app.complaints c join app.users u on u.id = c.user_id where c.id = $1", [id])).rows[0];
  if (!r) return c.json({ message: "Not found" }, 404);
  const comments = (await db.query("select id, added_by, comment, created_at from app.complaint_comments where complaint_id = $1 order by id", [id])).rows;
  return c.json({ data: { ...complaintOut(r), role: r.role, person: fullName(r), phone: phoneOf(r), comments: comments.map(commentOut) } });
});

/** Reply to the person and/or change the status. A reply shows up in the person's app. */
adminSafetyRoutes.put("/admin/complaints/:id", ...guard("complaint edit"), async (c) => {
  const db = c.get("db");
  const admin = c.get("user");
  const id = Number(c.req.param("id"));
  const b = await readBody(c);
  const comment = txt(b.comment, 2000);
  const status = ["pending", "investigating", "resolved"].includes(String(b.status)) ? String(b.status) : null;
  if (!comment && !status) return validationFailed(c, { comment: ["Write a reply or choose a status."] });
  if (!(await db.query("select 1 from app.complaints where id = $1", [id])).rowCount) return c.json({ message: "Not found" }, 404);
  if (comment) await db.query("insert into app.complaint_comments (complaint_id, user_id, added_by, comment) values ($1,$2,'admin',$3)", [id, admin.id, comment]);
  await db.query("update app.complaints set updated_at = now(), status = coalesce($2, status) where id = $1", [id, status]);
  await audit(c, "complaint", String(id), { status, replied: !!comment });
  return c.json({ message: "Saved" });
});
