import { Hono, type Context } from "hono";
import { z } from "zod";
import type { AppEnv } from "../env";
import { audit, guard, loadAccess } from "../lib/permissions";
import { readBody, validationFailed } from "../lib/legacy";
import { sendEmail } from "../lib/email";
import { adminEmails } from "./safety";
import {
  CATEGORIES, INCIDENT_STATUSES, SEVERITIES, STATUS_LABEL, canTransition, incidentView, isActive, isStatus, needsNote, TRANSITIONS,
  type IncidentStatus,
} from "../lib/safety-center";

/**
 * The Safety Center: SOS alerts and admin-raised incidents with a six-state workflow, assignment, notes, escalation and a full history.
 * Names, phone numbers, exact locations and addresses are hidden unless the admin holds "sos pii", and even then only through the
 * reveal call, which is recorded in the incident history and the audit log. Lists never carry them.
 */
export const adminSafetyCenterRoutes = new Hono<AppEnv>();
type C = Context<AppEnv>;
type Row = Record<string, unknown>;

const NAME = (a: string) => `coalesce(nullif(btrim(${a}.display_name), ''), nullif(btrim(concat_ws(' ', ${a}.first_name, ${a}.last_name)), ''), ${a}.username)`;
const idOf = (c: C) => { const n = Number(c.req.param("id")); return Number.isSafeInteger(n) && n > 0 ? n : null; };
const notFound = (c: C) => c.json({ status: false, code: "not_found", message: "Incident not found." }, 404);
const phoneOf = (u: Row | undefined) => (u?.contact_number ? `+${String(u.country_code ?? "").replace(/\D/g, "")}${String(u.contact_number).replace(/^0+/, "")}` : null);
const esc = (s: unknown) => String(s ?? "").replace(/[&<>"]/g, (ch) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[ch] as string));
const iso = (v: unknown) => (v ? new Date(v as string).toISOString() : null);

const SELECT = `select a.*, ${NAME("u")} as person_name, ${NAME("asg")} as assignee_name, ${NAME("hd")} as handler_name
                  from app.sos_alerts a
                  join app.users u on u.id = a.user_id
                  left join app.users asg on asg.id = a.assigned_to
                  left join app.users hd on hd.id = a.handled_by`;

// Lists and detail never carry names, phones or exact places, whatever the role. Only the logged reveal call does.
const view = (r: Row, _pii: boolean) => ({
  ...incidentView(r, { pii: false, names: { person: r.person_name as string, assignee: r.assignee_name as string, handler: r.handler_name as string } }),
  allowed_next: TRANSITIONS[r.status as IncidentStatus] ?? [],
});

async function adminHas(c: C, adminId: number, permission: string): Promise<boolean> {
  const row = (await c.get("db").query(
    `select u.user_type, u.status, r.is_super, coalesce(bool_or(p.permission = $2), false) as has
       from app.users u left join app.admin_roles r on r.id = u.admin_role_id left join app.admin_role_permissions p on p.role_id = r.id
      where u.id = $1 and u.deleted_at is null group by u.user_type, u.status, r.is_super`, [adminId, permission])).rows[0];
  if (!row || row.user_type !== "admin" || row.status !== "active") return false;
  return row.is_super === null || row.is_super === true || row.has === true;
}

// ---------------------------------------------------------------------------------------------------------------------
adminSafetyCenterRoutes.get("/admin/safety/incidents", ...guard("sos list"), async (c) => {
  const db = c.get("db");
  const access = await loadAccess(c);
  const pii = access.permissions.has("sos pii");
  const q = c.req.query();
  const where: string[] = [];
  const args: unknown[] = [];
  const add = (sql: string, v: unknown) => { args.push(v); where.push(sql.replace("?", `$${args.length}`)); };
  const status = q.status ?? "active";
  if (status === "active") where.push("a.status in ('open', 'acknowledged', 'investigating', 'escalated')");
  else if (isStatus(status)) add("a.status = ?", status);
  else if (status !== "all") return validationFailed(c, { status: ["Unknown status."] });
  if (q.severity) { if (!(SEVERITIES as readonly string[]).includes(q.severity)) return validationFailed(c, { severity: ["Unknown severity."] }); add("a.severity = ?", q.severity); }
  if (q.category) { if (!(CATEGORIES as readonly string[]).includes(q.category)) return validationFailed(c, { category: ["Unknown category."] }); add("a.category = ?", q.category); }
  if (q.assigned === "me") add("a.assigned_to = ?", c.get("user").id);
  else if (q.assigned === "unassigned") where.push("a.assigned_to is null");
  else if (q.assigned && /^\d{1,15}$/.test(q.assigned)) add("a.assigned_to = ?", Number(q.assigned));
  const needle = (q.q ?? "").trim();
  if (/^\d{1,15}$/.test(needle)) { args.push(Number(needle)); where.push(`(a.id = $${args.length} or a.ride_request_id = $${args.length})`); }
  const page = Math.max(Number(q.page) || 1, 1);
  const w = where.length ? "where " + where.join(" and ") : "";
  const total = Number((await db.query(`select count(*)::int n from app.sos_alerts a ${w}`, args)).rows[0].n);
  const rows = (await db.query(
    `${SELECT} ${w} order by (a.status in ('open', 'escalated')) desc,
       case a.severity when 'critical' then 0 when 'high' then 1 when 'medium' then 2 else 3 end, a.id desc limit 30 offset $${args.length + 1}`,
    [...args, (page - 1) * 30])).rows;
  const counts = (await db.query("select status, count(*)::int n from app.sos_alerts group by status")).rows;
  const byStatus: Record<string, number> = Object.fromEntries(INCIDENT_STATUSES.map((s) => [s, 0]));
  for (const r of counts) byStatus[String(r.status)] = Number(r.n);
  const safety = ((await db.query("select value from app.settings where key = 'safety'")).rows[0]?.value ?? {}) as Row;
  return c.json({
    status: true, can_see_personal_details: pii, settings: { notify_emails: String(safety.notify_emails ?? "") }, counts: { ...byStatus, active: byStatus.open + byStatus.acknowledged + byStatus.investigating + byStatus.escalated },
    labels: STATUS_LABEL, data: rows.map((r) => view(r, pii)),
    pagination: { page, total_pages: Math.max(Math.ceil(total / 30), 1), total },
  });
});

adminSafetyCenterRoutes.get("/admin/safety/assignees", ...guard("sos list"), async (c) => {
  const rows = (await c.get("db").query(
    `select u.id, ${NAME("u")} as name from app.users u left join app.admin_roles r on r.id = u.admin_role_id
      where u.user_type = 'admin' and u.status = 'active' and u.deleted_at is null
        and (r.id is null or r.is_super or exists (select 1 from app.admin_role_permissions p where p.role_id = r.id and p.permission = 'sos list'))
      order by name limit 100`)).rows;
  return c.json({ status: true, data: rows.map((r) => ({ id: Number(r.id), name: r.name })) });
});

adminSafetyCenterRoutes.get("/admin/safety/incidents/:id", ...guard("sos list"), async (c) => {
  const id = idOf(c);
  if (!id) return notFound(c);
  const db = c.get("db");
  const access = await loadAccess(c);
  const pii = access.permissions.has("sos pii");
  const row = (await db.query(`${SELECT} where a.id = $1`, [id])).rows[0];
  if (!row) return notFound(c);
  const history = (await db.query(
    `select e.id, e.action, e.from_value, e.to_value, e.note, e.detail, e.created_at, e.admin_id, ${NAME("ad")} as admin_name
       from app.safety_incident_events e left join app.users ad on ad.id = e.admin_id where e.incident_id = $1 order by e.id`, [id])).rows;
  const ride = row.ride_request_id
    ? (await db.query("select r.id, r.status, r.created_at, s.name as ride_type from app.ride_requests r left join app.services s on s.id = r.service_id where r.id = $1", [row.ride_request_id])).rows[0]
    : null;
  const status = row.status as IncidentStatus;
  return c.json({
    status: true, can_see_personal_details: pii,
    data: {
      ...view(row, pii),
      ride: ride ? { id: Number(ride.id), status: ride.status, ride_type: ride.ride_type, created_at: iso(ride.created_at) } : null,
      history: history.map((h) => ({
        id: Number(h.id), action: h.action, from: h.from_value, to: h.to_value, note: h.note, at: iso(h.created_at),
        admin: h.admin_id ? { id: Number(h.admin_id), name: h.admin_name } : null,
        detail: h.action === "reveal" ? { fields: (h.detail as Row)?.fields ?? null } : h.detail,
      })),
      actions: {
        change_status: access.permissions.has("sos edit") ? TRANSITIONS[status].filter((t) => t !== "escalated" || access.permissions.has("sos escalate")) : [],
        assign_self: access.permissions.has("sos edit") && isActive(status),
        assign_others: access.permissions.has("sos assign") && isActive(status),
        reveal: pii, escalate: access.permissions.has("sos escalate") && TRANSITIONS[status].includes("escalated"),
      },
    },
  });
});

// ---------------------------------------------------------------------------------------------------------------------
// Reveal: the only way to see names, phones and exact places. Needs "sos pii". Recorded every time.
// ---------------------------------------------------------------------------------------------------------------------
adminSafetyCenterRoutes.post("/admin/safety/incidents/:id/reveal", ...guard("sos pii"), async (c) => {
  const id = idOf(c);
  if (!id) return notFound(c);
  const db = c.get("db");
  const a = (await db.query("select * from app.sos_alerts where id = $1", [id])).rows[0];
  if (!a) return notFound(c);
  const ride = a.ride_request_id
    ? (await db.query("select id, status, rider_id, driver_id, pickup_address, dropoff_address from app.ride_requests where id = $1", [a.ride_request_id])).rows[0] : undefined;
  const person = (await db.query("select first_name, last_name, display_name, username, country_code, contact_number from app.users where id = $1", [a.user_id])).rows[0];
  const otherId = ride ? (Number(ride.rider_id) === Number(a.user_id) ? ride.driver_id : ride.rider_id) : null;
  const other = otherId ? (await db.query("select first_name, last_name, display_name, username, country_code, contact_number from app.users where id = $1", [otherId])).rows[0] : undefined;
  const veh = ride?.driver_id ? (await db.query("select vehicle_make, vehicle_model, vehicle_colour, vehicle_plate from app.driver_profiles where user_id = $1", [ride.driver_id])).rows[0] : undefined;
  const nm = (u: Row | undefined) => (u ? String(u.display_name || [u.first_name, u.last_name].filter(Boolean).join(" ") || u.username || "") : null);
  const fields = ["names", "phones", "exact_location", ...(ride ? ["addresses"] : []), ...(veh ? ["vehicle"] : [])];
  await db.query("insert into app.safety_incident_events (incident_id, action, admin_id, detail) values ($1, 'reveal', $2, $3)", [id, c.get("user").id, JSON.stringify({ fields })]);
  await audit(c, "safety_pii_view", String(id), { fields });
  return c.json({
    status: true, note: "This view has been recorded against your name.",
    data: {
      person: { name: nm(person), phone: phoneOf(person) }, other_party: other ? { name: nm(other), phone: phoneOf(other) } : null,
      location: a.latitude != null && a.longitude != null ? { lat: Number(a.latitude), lng: Number(a.longitude), map_url: `https://www.google.com/maps?q=${Number(a.latitude)},${Number(a.longitude)}` } : null,
      ride: ride ? { id: Number(ride.id), status: ride.status, pickup: ride.pickup_address, dropoff: ride.dropoff_address } : null,
      vehicle: veh ? { description: [veh.vehicle_colour, veh.vehicle_make, veh.vehicle_model].filter(Boolean).join(" "), plate: veh.vehicle_plate } : null,
    },
  });
});

// ---------------------------------------------------------------------------------------------------------------------
// Changing an incident. Each change locks the row, checks the rule, and writes the history and the audit row in the same transaction.
// ---------------------------------------------------------------------------------------------------------------------
async function change(c: C, id: number, fn: (a: Row) => Promise<{ error?: Response; event?: { action: string; from?: string | null; to?: string | null; note?: string | null; detail?: Record<string, unknown> }; set?: Record<string, unknown>; audit?: string; auditDetail?: Record<string, unknown>; after?: () => Promise<void> }>) {
  const db = c.get("db");
  await db.query("begin");
  try {
    const a = (await db.query("select * from app.sos_alerts where id = $1 for update", [id])).rows[0];
    if (!a) { await db.query("rollback"); return notFound(c); }
    const r = await fn(a);
    if (r.error) { await db.query("rollback"); return r.error; }
    const sets = Object.keys(r.set ?? {});
    if (sets.length) await db.query(`update app.sos_alerts set ${sets.map((k, i) => `${k} = $${i + 2}`).join(", ")}, updated_at = now() where id = $1`, [id, ...sets.map((k) => (r.set as Row)[k])]);
    if (r.event) await db.query("insert into app.safety_incident_events (incident_id, action, admin_id, from_value, to_value, note, detail) values ($1,$2,$3,$4,$5,$6,$7)",
      [id, r.event.action, c.get("user").id, r.event.from ?? null, r.event.to ?? null, r.event.note ?? null, JSON.stringify(r.event.detail ?? {})]);
    if (r.audit) await audit(c, r.audit, String(id), r.auditDetail ?? { from: r.event?.from ?? null, to: r.event?.to ?? null, ...(r.event?.detail ?? {}) });
    await db.query("commit");
    if (r.after) await r.after().catch((e) => console.error("safety follow-up failed", (e as Error).message));
    return null;
  } catch (e) {
    await db.query("rollback").catch(() => {});
    throw e;
  }
}
const bad = (c: C, code: string, message: string, status: 409 | 403 | 422 = 409) => c.json({ status: false, code, message }, status);
const note = z.string().trim().min(3, "Write at least 3 characters.").max(1000);

adminSafetyCenterRoutes.put("/admin/safety/incidents/:id/status", ...guard("sos edit"), async (c) => {
  const id = idOf(c);
  if (!id) return notFound(c);
  const p = z.object({ status: z.enum(INCIDENT_STATUSES), note: z.string().trim().max(1000).optional() }).safeParse(await readBody(c));
  if (!p.success) return validationFailed(c, { status: ["Choose a valid status."] });
  const to = p.data.status;
  const access = await loadAccess(c);
  if (to === "escalated" && !access.permissions.has("sos escalate")) return bad(c, "forbidden", "You do not have permission to escalate incidents.", 403);
  if (needsNote(to) && !note.safeParse(p.data.note).success) return validationFailed(c, { note: ["Say why (at least 3 characters)."] });
  const out = await change(c, id, async (a) => {
    const from = String(a.status);
    if (from === to) return { error: bad(c, "no_change", `The incident is already ${STATUS_LABEL[to]}.`) };
    if (!canTransition(from, to)) return { error: bad(c, "invalid_transition", `An incident that is ${STATUS_LABEL[from as IncidentStatus]} cannot move to ${STATUS_LABEL[to]}.`) };
    const set: Row = { status: to, handled_by: c.get("user").id, handled_at: new Date() };
    if (p.data.note) set.admin_note = p.data.note;
    if (to === "closed") set.closed_at = new Date();
    return {
      set, event: { action: to === "escalated" ? "escalated" : "status", from, to, note: p.data.note ?? null }, audit: to === "escalated" ? "safety_escalate" : "safety_status",
      after: to === "escalated" ? async () => {
        // Tell the people on the safety email list. No names, phones or places: only what they need to open the Safety Center.
        const recipients = await adminEmails(c.get("db"));
        const html = `<h2>Safety incident #${id} escalated</h2><p>Category: ${esc(a.category)} · Severity: ${esc(a.severity)}${a.ride_request_id ? ` · Trip #${esc(a.ride_request_id)}` : ""}</p><p>Reason: ${esc(p.data.note)}</p><p>Open Admin, Safety Center to act.</p>`;
        await Promise.all(recipients.map((email) => sendEmail(c.get("db"), c.env.SETTINGS_ENCRYPTION_KEY, { to: email, subject: `Safety incident #${id} escalated`, html })));
      } : undefined,
    };
  });
  return out ?? c.json({ status: true, message: `Marked as ${STATUS_LABEL[to].toLowerCase()}.` });
});

adminSafetyCenterRoutes.put("/admin/safety/incidents/:id/assign", ...guard("sos edit"), async (c) => {
  const id = idOf(c);
  if (!id) return notFound(c);
  const p = z.object({ admin_id: z.number().int().positive().nullable() }).safeParse(await readBody(c));
  if (!p.success) return validationFailed(c, { admin_id: ["Choose an administrator, or none."] });
  const me = c.get("user").id;
  const access = await loadAccess(c);
  const target = p.data.admin_id;
  if (target !== null && Number(target) !== Number(me) && !access.permissions.has("sos assign")) return bad(c, "forbidden", "You can assign an incident to yourself only.", 403);
  if (target !== null && !(await adminHas(c, target, "sos list"))) return bad(c, "not_assignable", "That administrator cannot work on safety incidents.", 422);
  const out = await change(c, id, async (a) => {
    if (!isActive(String(a.status))) return { error: bad(c, "not_active", "A resolved or closed incident cannot be assigned.") };
    const from = a.assigned_to == null ? null : String(a.assigned_to);
    if ((target === null && from === null) || (target !== null && from === String(target))) return { error: bad(c, "no_change", "Nothing to change.") };
    if (target === null && from !== null && Number(from) !== Number(me) && !access.permissions.has("sos assign")) return { error: bad(c, "forbidden", "Only the assignee or someone who can assign may remove the assignment.", 403) };
    return { set: { assigned_to: target }, event: { action: "assigned", from, to: target === null ? null : String(target) }, audit: "safety_assign" };
  });
  return out ?? c.json({ status: true, message: target === null ? "Assignment removed." : "Assigned." });
});

adminSafetyCenterRoutes.put("/admin/safety/incidents/:id/classify", ...guard("sos edit"), async (c) => {
  const id = idOf(c);
  if (!id) return notFound(c);
  const p = z.object({ category: z.enum(CATEGORIES).optional(), severity: z.enum(SEVERITIES).optional(), note: z.string().trim().max(1000).optional() }).safeParse(await readBody(c));
  if (!p.success || (!p.data.category && !p.data.severity)) return validationFailed(c, { category: ["Choose a category or a severity."] });
  const out = await change(c, id, async (a) => {
    if (!isActive(String(a.status))) return { error: bad(c, "not_active", "A resolved or closed incident cannot be reclassified.") };
    const changes: string[] = [];
    const set: Row = {};
    if (p.data.category && p.data.category !== a.category) { set.category = p.data.category; changes.push(`category ${a.category} to ${p.data.category}`); }
    if (p.data.severity && p.data.severity !== a.severity) { set.severity = p.data.severity; changes.push(`severity ${a.severity} to ${p.data.severity}`); }
    if (!changes.length) return { error: bad(c, "no_change", "Nothing to change.") };
    // One history row per field, so each is searchable on its own.
    for (const k of Object.keys(set)) {
      await c.get("db").query("insert into app.safety_incident_events (incident_id, action, admin_id, from_value, to_value, note) values ($1,$2,$3,$4,$5,$6)", [id, k, c.get("user").id, a[k], set[k], p.data.note ?? null]);
    }
    return { set, audit: "safety_classify", auditDetail: { changes } };
  });
  return out ?? c.json({ status: true, message: "Updated." });
});

adminSafetyCenterRoutes.post("/admin/safety/incidents/:id/notes", ...guard("sos edit"), async (c) => {
  const id = idOf(c);
  if (!id) return notFound(c);
  const p = z.object({ note }).safeParse(await readBody(c));
  if (!p.success) return validationFailed(c, { note: [p.error.issues[0]?.message ?? "Write a note."] });
  const out = await change(c, id, async (a) => {
    if (String(a.status) === "closed") return { error: bad(c, "not_active", "A closed incident cannot take new notes.") };
    return { set: { admin_note: p.data.note }, event: { action: "note", note: p.data.note }, audit: "safety_note", };
  });
  return out ?? c.json({ status: true, message: "Note added." });
});

// An administrator can raise an incident from a trip (a complaint by phone, a report from a driver, something seen on the map).
adminSafetyCenterRoutes.post("/admin/safety/incidents", ...guard("sos edit"), async (c) => {
  const p = z.object({
    ride_request_id: z.number().int().positive(), party: z.enum(["rider", "driver"]), category: z.enum(CATEGORIES).default("other"),
    severity: z.enum(SEVERITIES).default("medium"), note,
  }).safeParse(await readBody(c));
  if (!p.success) return validationFailed(c, { ride_request_id: ["Enter the trip number, who it concerns, a category and a note."] });
  const db = c.get("db");
  const ride = (await db.query("select id, status, rider_id, driver_id from app.ride_requests where id = $1", [p.data.ride_request_id])).rows[0];
  if (!ride) return c.json({ status: false, code: "ride_not_found", message: "Trip not found." }, 404);
  const userId = p.data.party === "driver" ? ride.driver_id : ride.rider_id;
  if (!userId) return bad(c, "no_driver", "That trip has no driver yet.", 422);
  await db.query("begin");
  try {
    const nm = (await db.query(`select ${NAME("u")} as name from app.users u where u.id = $1`, [userId])).rows[0]?.name ?? null;
    const id = Number((await db.query(
      `insert into app.sos_alerts (user_id, role, ride_request_id, message, context, category, severity, source)
       values ($1,$2,$3,$4,$5::jsonb,$6,$7,'admin') returning id`,
      [userId, p.data.party, ride.id, p.data.note, JSON.stringify({ person: { name: nm }, ride: { id: Number(ride.id), status: ride.status } }), p.data.category, p.data.severity])).rows[0].id);
    await db.query("insert into app.safety_incident_events (incident_id, action, admin_id, to_value, note, detail) values ($1,'created',$2,'open',$3,$4)",
      [id, c.get("user").id, p.data.note, JSON.stringify({ source: "admin", category: p.data.category, severity: p.data.severity })]);
    await audit(c, "safety_create", String(id), { ride_request_id: Number(ride.id), party: p.data.party, category: p.data.category, severity: p.data.severity });
    await db.query("commit");
    return c.json({ status: true, id, message: "Incident raised." }, 201);
  } catch (e) {
    await db.query("rollback").catch(() => {});
    throw e;
  }
});
