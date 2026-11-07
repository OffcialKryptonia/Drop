import { Hono, type Context } from "hono";
import { z } from "zod";
import type { AppEnv } from "../env";
import { withDb } from "../db";
import { requireAuth } from "../auth/middleware";
import { readBody, validationFailed } from "../lib/legacy";
import { MAX_UPLOAD_BYTES, newKey, sniff } from "../lib/files";
import { EDITABLE, ageOn, documentsFor, ensureProfile, getSetting, missingForSubmit, validDate } from "../lib/driver-application";

export const driverApplicationRoutes = new Hono<AppEnv>();
type C = Context<AppEnv>;

const riderOrDriver = async (c: C, next: () => Promise<void>) => {
  const t = c.get("user").user_type;
  if (t !== "rider" && t !== "driver") return c.json({ message: "Forbidden" }, 403);
  await next();
};
const mw = [withDb, requireAuth, riderOrDriver] as const;
const idOf = (s: string) => (/^\d{1,15}$/.test(s) ? Number(s) : null);
const errs = (e: z.ZodError) => {
  const out: Record<string, string[]> = {};
  for (const i of e.issues) (out[String(i.path.join(".") || "body")] ??= []).push(i.message);
  return out;
};
const text = (max: number, label: string) => z.string({ error: `The ${label} is required.` }).trim().min(1, `The ${label} is required.`).max(max);

/** The profile row, or null if the person has not started an application. */
const profileOf = async (c: C) => (await c.get("db").query("select * from app.driver_profiles where user_id = $1", [c.get("user").id])).rows[0] ?? null;
const editableOrReply = (c: C, p: { status: string } | null) =>
  p && !EDITABLE.includes(p.status)
    ? c.json({ message: "This application is locked while it is under review or approved.", code: "locked", status: 409 }, 409)
    : null;
/** Editing a rejected application starts a fresh draft. */
const reopen = (c: C, p: { status: string } | null) =>
  p?.status === "rejected" ? c.get("db").query("update app.driver_profiles set status = 'draft', review_note = null where user_id = $1", [c.get("user").id]) : Promise.resolve();

/** What the app needs to draw the registration form: rules, ride types and required documents. All admin data. */
driverApplicationRoutes.get("/driver/requirements", ...mw, async (c) => {
  const db = c.get("db");
  const vehicles = (await db.query(
    `select id, name, category, icon_url, photo_url, capacity from app.services
      where status = true and deleted_at is null order by sort_order, id`)).rows;
  const documents = (await db.query(
    `select d.id, d.name, d.is_required as required, d.has_expiry_date,
            coalesce((select array_agg(r.service_id order by r.service_id) from app.document_requirements r where r.document_id = d.id), '{}') as service_ids
       from app.documents d where d.status and d.type = 'driver' order by d.is_required desc, d.id`)).rows;
  return c.json({
    min_age: await getSetting(db, "driver_min_age", 19),
    min_licence_years: await getSetting(db, "driver_min_licence_years", 1),
    max_upload_mb: MAX_UPLOAD_BYTES / 1024 / 1024,
    vehicles, documents, // a document with service_ids [] applies to every ride type
  });
});

/** The applicant's own draft and review status. */
driverApplicationRoutes.get("/driver/application", ...mw, async (c) => {
  const me = c.get("user");
  const db = c.get("db");
  const p = await profileOf(c);
  const u = (await db.query("select first_name, last_name, (profile_image_key is not null) as has_photo from app.users where id = $1", [me.id])).rows[0];
  if (!p) return c.json({ status: "not_started", editable: true, personal: { first_name: u.first_name, last_name: u.last_name, has_photo: u.has_photo }, vehicle: null, documents: [] });
  return c.json({
    status: p.status,
    editable: EDITABLE.includes(p.status),
    review_note: p.review_note,
    submitted_at: p.submitted_at,
    personal: { first_name: u.first_name, last_name: u.last_name, date_of_birth: p.date_of_birth ? String(p.date_of_birth).slice(0, 10) : null, has_photo: u.has_photo },
    vehicle: { service_id: p.service_id, licence_years: p.licence_years, make: p.vehicle_make, model: p.vehicle_model, year: p.vehicle_year, colour: p.vehicle_colour, plate: p.vehicle_plate, seats: p.vehicle_seats },
    documents: (await documentsFor(db, me.id, p.service_id)).map((d) => ({
      document_id: d.document_id, name: d.name, required: d.required, has_expiry_date: d.has_expiry_date, uploaded: d.uploaded,
      expire_date: d.expire_date ? String(d.expire_date).slice(0, 10) : null,
      status: !d.uploaded ? "missing" : d.is_verified === 1 ? "approved" : d.is_verified === 2 ? "rejected" : "pending", note: d.admin_note,
    })),
  });
});

driverApplicationRoutes.put("/driver/application/personal", ...mw, async (c) => {
  const p = z.object({
    first_name: text(100, "first name"), last_name: text(100, "surname"),
    date_of_birth: z.string({ error: "The date of birth is required." }).refine(validDate, "Enter a valid date (YYYY-MM-DD)."),
  }).safeParse(await readBody(c));
  if (!p.success) return validationFailed(c, errs(p.error));
  const db = c.get("db");
  const minAge = await getSetting(db, "driver_min_age", 19);
  const age = ageOn(p.data.date_of_birth);
  if (age < minAge) return validationFailed(c, { date_of_birth: [`You must be at least ${minAge} years old to drive.`] });
  if (age > 100) return validationFailed(c, { date_of_birth: ["Enter a valid date of birth."] });

  const existing = await profileOf(c);
  const locked = editableOrReply(c, existing);
  if (locked) return locked;
  await ensureProfile(db, c.get("user").id);
  await reopen(c, existing);
  await db.query("update app.users set first_name = $2, last_name = $3, display_name = $4 where id = $1",
    [c.get("user").id, p.data.first_name, p.data.last_name, `${p.data.first_name} ${p.data.last_name}`]);
  await db.query("update app.driver_profiles set date_of_birth = $2 where user_id = $1", [c.get("user").id, p.data.date_of_birth]);
  return c.json({ message: "Saved" });
});

driverApplicationRoutes.put("/driver/application/vehicle", ...mw, async (c) => {
  const p = z.object({
    service_id: z.coerce.number().int().positive({ error: "Choose your vehicle." }),
    licence_years: z.coerce.number().int().min(0).max(80),
    make: text(60, "make"), model: text(60, "model"), colour: text(40, "colour"),
    year: z.string().trim().regex(/^(19|20)\d{2}$/, "Enter a valid year."),
    plate: text(20, "plate number"),
    seats: z.coerce.number().int().min(1).max(60),
  }).safeParse(await readBody(c));
  if (!p.success) return validationFailed(c, errs(p.error));
  const db = c.get("db");
  const svc = (await db.query("select capacity from app.services where id = $1 and status = true and deleted_at is null", [p.data.service_id])).rows[0];
  if (!svc) return validationFailed(c, { service_id: ["This vehicle type is not available."] });
  if (svc.capacity && p.data.seats > svc.capacity) return validationFailed(c, { seats: [`This vehicle type seats at most ${svc.capacity}.`] });

  const existing = await profileOf(c);
  const locked = editableOrReply(c, existing);
  if (locked) return locked;
  await ensureProfile(db, c.get("user").id);
  await reopen(c, existing);
  await db.query(
    `update app.driver_profiles set service_id = $2, licence_years = $3, vehicle_make = $4, vehicle_model = $5, vehicle_colour = $6,
            vehicle_year = $7, vehicle_plate = upper($8), vehicle_seats = $9 where user_id = $1`,
    [c.get("user").id, p.data.service_id, p.data.licence_years, p.data.make, p.data.model, p.data.colour, p.data.year, p.data.plate, p.data.seats]);
  return c.json({ message: "Saved" });
});

/** Reads an upload body, checks its size and what the file really is. Returns a reply on failure. */
async function readUpload(c: C) {
  if (!c.env.DOCS) return { reply: c.json({ message: "File uploads are not set up yet.", status: 503 }, 503) };
  const declared = Number(c.req.header("content-length") ?? 0);
  if (declared > MAX_UPLOAD_BYTES) return { reply: c.json({ message: "That file is too large (5 MB maximum).", status: 413 }, 413) };
  const bytes = new Uint8Array(await c.req.arrayBuffer());
  if (bytes.length === 0) return { reply: c.json({ message: "No file received.", status: 422 }, 422) };
  if (bytes.length > MAX_UPLOAD_BYTES) return { reply: c.json({ message: "That file is too large (5 MB maximum).", status: 413 }, 413) };
  const kind = sniff(bytes);
  if (!kind) return { reply: c.json({ message: "Upload a JPG, PNG, WebP or PDF file.", status: 415 }, 415) };
  return { bytes, kind };
}

/** Profile photo: raw image bytes in the body. */
driverApplicationRoutes.put("/driver/application/photo", ...mw, async (c) => {
  const existing = await profileOf(c);
  const locked = editableOrReply(c, existing);
  if (locked) return locked;
  const up = await readUpload(c);
  if ("reply" in up) return up.reply;
  if (up.kind.type === "application/pdf") return c.json({ message: "The photo must be an image.", status: 415 }, 415);
  const me = c.get("user");
  const db = c.get("db");
  const key = newKey(`drivers/${me.id}`, "photo", up.kind.ext);
  await c.env.DOCS!.put(key, up.bytes, { httpMetadata: { contentType: up.kind.type } });
  const old = (await db.query("select profile_image_key from app.users where id = $1", [me.id])).rows[0]?.profile_image_key as string | null;
  await db.query("update app.users set profile_image_key = $2 where id = $1", [me.id, key]);
  if (old) await c.env.DOCS!.delete(old).catch(() => undefined);
  await ensureProfile(db, me.id);
  await reopen(c, existing);
  return c.json({ message: "Saved" });
});

/** One required document: raw file bytes in the body, ?expire_date=YYYY-MM-DD when the document expires. */
driverApplicationRoutes.put("/driver/documents/:documentId", ...mw, async (c) => {
  const docId = idOf(c.req.param("documentId"));
  if (!docId) return c.json({ message: "Not found", status: 404 }, 404);
  const db = c.get("db");
  const doc = (await db.query("select id, has_expiry_date from app.documents where id = $1 and status and type = 'driver'", [docId])).rows[0];
  if (!doc) return c.json({ message: "Not found", status: 404 }, 404);
  const expire = c.req.query("expire_date") ?? null;
  if (doc.has_expiry_date) {
    if (!validDate(expire) || new Date(expire) <= new Date()) return validationFailed(c, { expire_date: ["Enter the expiry date (it must be in the future)."] });
  }
  const existing = await profileOf(c);
  const locked = editableOrReply(c, existing);
  if (locked) return locked;
  const up = await readUpload(c);
  if ("reply" in up) return up.reply;

  const me = c.get("user");
  const key = newKey(`drivers/${me.id}`, `doc${docId}`, up.kind.ext);
  await c.env.DOCS!.put(key, up.bytes, { httpMetadata: { contentType: up.kind.type } });
  await ensureProfile(db, me.id);
  await reopen(c, existing);
  const old = (await db.query("select file_key from app.driver_documents where driver_id = $1 and document_id = $2", [me.id, docId])).rows[0]?.file_key as string | undefined;
  await db.query(
    `insert into app.driver_documents (driver_id, document_id, file_key, content_type, size_bytes, uploaded_at, expire_date, is_verified, admin_note)
     values ($1,$2,$3,$4,$5, now(), $6, 0, null)
     on conflict (driver_id, document_id) do update set file_key = excluded.file_key, content_type = excluded.content_type,
       size_bytes = excluded.size_bytes, uploaded_at = now(), expire_date = excluded.expire_date, is_verified = 0, admin_note = null, reminder_sent = false`,
    [me.id, docId, key, up.kind.type, up.bytes.length, doc.has_expiry_date ? expire : null]);
  if (old) await c.env.DOCS!.delete(old).catch(() => undefined);
  return c.json({ message: "Saved" });
});

/** The owner's own uploaded file, so the app can show a preview. Never cached, never public. */
driverApplicationRoutes.get("/driver/documents/:documentId/file", ...mw, async (c) => {
  const docId = idOf(c.req.param("documentId"));
  if (!docId || !c.env.DOCS) return c.json({ message: "Not found", status: 404 }, 404);
  const key = (await c.get("db").query("select file_key from app.driver_documents where driver_id = $1 and document_id = $2", [c.get("user").id, docId])).rows[0]?.file_key;
  return key ? serveFile(c, key) : c.json({ message: "Not found", status: 404 }, 404);
});

export async function serveFile(c: C, key: string) {
  const obj = await c.env.DOCS!.get(key);
  if (!obj) return c.json({ message: "Not found", status: 404 }, 404);
  return new Response(obj.body, {
    headers: {
      "Content-Type": obj.httpMetadata?.contentType ?? "application/octet-stream",
      "Cache-Control": "private, no-store",
      "X-Content-Type-Options": "nosniff",
      "Content-Disposition": "inline",
    },
  });
}

driverApplicationRoutes.post("/driver/application/submit", ...mw, async (c) => {
  const db = c.get("db");
  const p = await profileOf(c);
  if (!p) return c.json({ message: "Start your application first.", status: 422 }, 422);
  if (!["draft", "needs_changes"].includes(p.status)) return c.json({ message: "This application cannot be submitted right now.", code: "locked", status: 409 }, 409);
  const missing = await missingForSubmit(db, c.get("user").id, await getSetting(db, "driver_min_age", 19), await getSetting(db, "driver_min_licence_years", 1));
  if (missing.length) return c.json({ message: "Your application is not complete.", missing, status: 422 }, 422);
  await db.query("update app.driver_profiles set status = 'submitted', submitted_at = now(), review_note = null where user_id = $1", [c.get("user").id]);
  return c.json({ message: "Submitted", status: "submitted" });
});
