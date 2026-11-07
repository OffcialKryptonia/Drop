import { Hono, type Context } from "hono";
import { z } from "zod";
import type { AppEnv } from "../env";
import { audit, guard } from "../lib/permissions";
import { readBody, validationFailed } from "../lib/legacy";
import { documentsFor } from "../lib/driver-application";
import { serveFile } from "./driver-application";

export const adminDriverApplicationRoutes = new Hono<AppEnv>();
type C = Context<AppEnv>;
const idParam = (c: C, name = "id") => { const s = c.req.param(name) ?? ""; return /^\d{1,15}$/.test(s) ? Number(s) : null; };
const notFound = (c: C) => c.json({ message: "Not found", status: 404 }, 404);

const STATUSES = ["draft", "submitted", "in_review", "needs_changes", "approved", "rejected", "suspended"];

/** Applications, newest submission first. Default view is the review queue. */
adminDriverApplicationRoutes.get("/admin/driver-applications", ...guard("driver_application list"), async (c) => {
  const db = c.get("db");
  const status = c.req.query("status") ?? "queue";
  const q = (c.req.query("q") ?? "").trim();
  const perPage = Math.min(Math.max(Number(c.req.query("per_page")) || 20, 1), 100);
  const page = Math.max(Number(c.req.query("page")) || 1, 1);

  const where = ["u.deleted_at is null"];
  const params: unknown[] = [];
  if (status === "queue") where.push("p.status in ('submitted', 'in_review')");
  else if (status !== "all") {
    if (!STATUSES.includes(status)) return c.json({ message: "Unknown status", status: 422 }, 422);
    params.push(status); where.push(`p.status = $${params.length}`);
  }
  if (q) { params.push(`%${q}%`); where.push(`(u.email ilike $${params.length} or u.first_name ilike $${params.length} or u.last_name ilike $${params.length} or u.contact_number ilike $${params.length} or p.vehicle_plate ilike $${params.length})`); }
  const from = `from app.driver_profiles p join app.users u on u.id = p.user_id where ${where.join(" and ")}`;
  const total = (await db.query(`select count(*)::int n ${from}`, params)).rows[0].n;
  const rows = (await db.query(
    `select u.id, u.first_name, u.last_name, u.email, u.contact_number, p.status, p.submitted_at, p.reviewed_at, p.vehicle_make, p.vehicle_model, p.vehicle_plate,
            (select name from app.services s where s.id = p.service_id) as ride_type
       ${from} order by p.submitted_at desc nulls last, u.id desc limit ${perPage} offset ${(page - 1) * perPage}`, params)).rows;
  const counts = (await db.query("select status, count(*)::int n from app.driver_profiles group by status")).rows;
  return c.json({ data: rows, counts: Object.fromEntries(counts.map((r) => [r.status, r.n])), pagination: { page, per_page: perPage, total, total_pages: Math.max(Math.ceil(total / perPage), 1) } });
});

adminDriverApplicationRoutes.get("/admin/driver-applications/:id", ...guard("driver_application list"), async (c) => {
  const id = idParam(c); if (!id) return notFound(c);
  const db = c.get("db");
  const r = (await db.query(
    `select u.id, u.first_name, u.last_name, u.email, u.contact_number, u.status as account_status, (u.profile_image_key is not null) as has_photo,
            p.*, (select name from app.services s where s.id = p.service_id) as ride_type
       from app.driver_profiles p join app.users u on u.id = p.user_id where p.user_id = $1 and u.deleted_at is null`, [id])).rows[0];
  if (!r) return notFound(c);
  const documents = (await documentsFor(db, id, r.service_id)).map((d) => ({
    document_id: d.document_id, name: d.name, required: d.required, has_expiry_date: d.has_expiry_date, uploaded: d.uploaded,
    expire_date: d.expire_date ? String(d.expire_date).slice(0, 10) : null, uploaded_at: d.uploaded_at, content_type: d.content_type,
    status: !d.uploaded ? "missing" : d.is_verified === 1 ? "approved" : d.is_verified === 2 ? "rejected" : "pending", note: d.admin_note,
  }));
  const { user_id, ...profile } = r;
  return c.json({ data: { ...profile, id, documents } });
});

adminDriverApplicationRoutes.get("/admin/driver-applications/:id/photo", ...guard("driver_application list"), async (c) => {
  const id = idParam(c); if (!id || !c.env.DOCS) return notFound(c);
  const key = (await c.get("db").query("select profile_image_key from app.users where id = $1", [id])).rows[0]?.profile_image_key;
  return key ? serveFile(c, key) : notFound(c);
});

adminDriverApplicationRoutes.get("/admin/driver-applications/:id/documents/:docId/file", ...guard("driver_application list"), async (c) => {
  const id = idParam(c), docId = idParam(c, "docId"); if (!id || !docId || !c.env.DOCS) return notFound(c);
  const key = (await c.get("db").query("select file_key from app.driver_documents where driver_id = $1 and document_id = $2", [id, docId])).rows[0]?.file_key;
  return key ? serveFile(c, key) : notFound(c);
});

/** Approve, reject or ask for a re-upload of ONE document. */
adminDriverApplicationRoutes.put("/admin/driver-applications/:id/documents/:docId", ...guard("driver_application edit"), async (c) => {
  const id = idParam(c), docId = idParam(c, "docId"); if (!id || !docId) return notFound(c);
  const p = z.object({ status: z.enum(["approved", "rejected", "pending"]), note: z.string().trim().max(300).optional() }).safeParse(await readBody(c));
  if (!p.success) return validationFailed(c, { status: ["Choose approved, rejected or pending."] });
  if (p.data.status === "rejected" && !p.data.note) return validationFailed(c, { note: ["Tell the driver what is wrong with this document."] });
  const r = await c.get("db").query(
    "update app.driver_documents set is_verified = $3, admin_note = $4 where driver_id = $1 and document_id = $2 and file_key is not null",
    [id, docId, p.data.status === "approved" ? 1 : p.data.status === "rejected" ? 2 : 0, p.data.status === "approved" ? null : p.data.note ?? null]);
  if (!r.rowCount) return notFound(c);
  await audit(c, "driver_document", String(id), { document_id: docId, status: p.data.status });
  return c.json({ message: "Saved" });
});

const FROM: Record<string, string[]> = {
  start_review: ["submitted"],
  approve: ["submitted", "in_review"],
  reject: ["submitted", "in_review"],
  needs_changes: ["submitted", "in_review"],
  suspend: ["approved"],
  reinstate: ["suspended"],
};
const NEEDS_NOTE = ["reject", "needs_changes", "suspend"];

/** The decision on an application. Every decision is audited with who made it. */
adminDriverApplicationRoutes.post("/admin/driver-applications/:id/review", ...guard("driver_application edit"), async (c) => {
  const id = idParam(c); if (!id) return notFound(c);
  const p = z.object({ action: z.enum(["start_review", "approve", "reject", "needs_changes", "suspend", "reinstate"]), note: z.string().trim().max(300).optional() }).safeParse(await readBody(c));
  if (!p.success) return validationFailed(c, { action: ["Unknown action."] });
  const { action, note } = p.data;
  if (NEEDS_NOTE.includes(action) && !note) return validationFailed(c, { note: ["Write a reason the driver will see."] });

  const db = c.get("db");
  const admin = c.get("user").id;
  try {
    await db.query("begin");
    const prof = (await db.query("select p.status, p.service_id, u.user_type from app.driver_profiles p join app.users u on u.id = p.user_id where p.user_id = $1 for update of p", [id])).rows[0];
    if (!prof) { await db.query("rollback"); return notFound(c); }
    if (!FROM[action].includes(prof.status)) {
      await db.query("rollback");
      return c.json({ message: `This application is ${prof.status.replace("_", " ")}, so it cannot be ${action.replace("_", " ")}d.`, code: "bad_state", status: 409 }, 409);
    }

    let next = prof.status;
    if (action === "start_review") next = "in_review";
    if (action === "needs_changes") next = "needs_changes";
    if (action === "reject") next = "rejected";
    if (action === "suspend") next = "suspended";
    if (action === "reinstate") next = "approved";

    if (action === "approve") {
      const docs = await documentsFor(db, id, prof.service_id);
      const pending = docs.filter((d) => d.required && (!d.uploaded || d.is_verified !== 1)).map((d) => ({ document_id: d.document_id, name: d.name }));
      if (!prof.service_id || pending.length) {
        await db.query("rollback");
        return c.json({ message: "Approve every required document first.", code: "documents_not_approved", missing: pending, status: 409 }, 409);
      }
      next = "approved";
      await db.query("update app.users set is_verified_driver = true, service_id = $2 where id = $1", [id, prof.service_id]);
      await db.query("delete from app.driver_services where driver_id = $1", [id]);
      await db.query("insert into app.driver_services (driver_id, service_id) values ($1, $2)", [id, prof.service_id]);
    }
    if (action === "suspend") await db.query("update app.users set is_online = false, is_available = false, active_mode = 'rider' where id = $1", [id]);
    // Accounts created through the old driver app also carry the account status.
    if (prof.user_type === "driver") {
      const acct = action === "approve" || action === "reinstate" ? "active" : action === "reject" ? "reject" : action === "suspend" ? "inactive" : null;
      if (acct) await db.query("update app.users set status = $2 where id = $1", [id, acct]);
    }
    await db.query(
      `update app.driver_profiles set status = $2, reviewed_by = $3, reviewed_at = now(), review_note = $4 where user_id = $1`,
      [id, next, admin, action === "approve" || action === "reinstate" || action === "start_review" ? null : note ?? null]);
    await audit(c, `driver_${action}`, String(id), { from: prof.status, to: next, note: note ?? null });
    await db.query("commit");
    return c.json({ message: "Saved", status: next });
  } catch (e) {
    await db.query("rollback").catch(() => undefined);
    throw e;
  }
});
