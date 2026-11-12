import { Hono } from "hono";
import type { AppEnv } from "../env";
import { guard } from "../lib/permissions";
import { readBody, validationFailed } from "../lib/legacy";

export const adminDocumentRoutes = new Hono<AppEnv>();

/** Document types drivers must upload (licence, vehicle papers, ...), the ride types they apply to, and the age/licence rules. */
adminDocumentRoutes.get("/admin/documents", ...guard("document list"), async (c) => {
  const db = c.get("db");
  const docs = (await db.query(
    `select d.id, d.name, d.is_required, d.has_expiry_date, d.status,
            coalesce((select array_agg(r.service_id order by r.service_id) from app.document_requirements r where r.document_id = d.id), '{}') as service_ids,
            (select count(*)::int from app.driver_documents x where x.document_id = d.id and x.file_key is not null) as uploads
       from app.documents d where d.type = 'driver' order by d.id`)).rows;
  const services = (await db.query("select id, name from app.services where deleted_at is null order by sort_order, id")).rows;
  const s = Object.fromEntries((await db.query("select key, value from app.settings where key in ('driver_min_age','driver_min_licence_years')")).rows.map((r) => [r.key, r.value]));
  return c.json({ data: docs, services, rules: { min_age: Number(s.driver_min_age ?? 19), min_licence_years: Number(s.driver_min_licence_years ?? 1) } });
});

const parse = (b: Record<string, unknown>) => {
  const name = String(b.name ?? "").trim().slice(0, 100);
  const ids = Array.isArray(b.service_ids) ? [...new Set(b.service_ids.map(Number).filter((n) => Number.isInteger(n) && n > 0))] : [];
  return { name, required: b.is_required !== false, expiry: b.has_expiry_date === true, status: b.status !== false, ids };
};

adminDocumentRoutes.post("/admin/documents", ...guard("document edit"), async (c) => {
  const db = c.get("db");
  const d = parse(await readBody(c));
  if (!d.name) return validationFailed(c, { name: ["Give the document a name, e.g. Driver's licence."] });
  await db.query("begin");
  try {
    const id = (await db.query("insert into app.documents (name, type, is_required, has_expiry_date, status) values ($1,'driver',$2,$3,$4) returning id", [d.name, d.required, d.expiry, d.status])).rows[0].id;
    for (const sid of d.ids) await db.query("insert into app.document_requirements (document_id, service_id) values ($1,$2) on conflict do nothing", [id, sid]);
    await db.query("commit");
  } catch (e) { await db.query("rollback").catch(() => undefined); throw e; }
  return c.json({ message: "Document type added" });
});

adminDocumentRoutes.put("/admin/documents/:id", ...guard("document edit"), async (c) => {
  const db = c.get("db");
  const id = Number(c.req.param("id"));
  const d = parse(await readBody(c));
  if (!d.name) return validationFailed(c, { name: ["Give the document a name."] });
  await db.query("begin");
  try {
    const r = await db.query("update app.documents set name=$2, is_required=$3, has_expiry_date=$4, status=$5, updated_at=now() where id=$1 and type='driver'", [id, d.name, d.required, d.expiry, d.status]);
    if (!r.rowCount) { await db.query("rollback"); return c.json({ message: "Not found" }, 404); }
    await db.query("delete from app.document_requirements where document_id = $1", [id]);
    for (const sid of d.ids) await db.query("insert into app.document_requirements (document_id, service_id) values ($1,$2) on conflict do nothing", [id, sid]);
    await db.query("commit");
  } catch (e) { await db.query("rollback").catch(() => undefined); throw e; }
  return c.json({ message: "Saved" });
});

/** A type drivers already uploaded files for is switched off instead of deleted, so their records stay. */
adminDocumentRoutes.delete("/admin/documents/:id", ...guard("document edit"), async (c) => {
  const db = c.get("db");
  const id = Number(c.req.param("id"));
  const used = (await db.query("select 1 from app.driver_documents where document_id = $1 limit 1", [id])).rowCount;
  if (used) {
    await db.query("update app.documents set status = false, updated_at = now() where id = $1", [id]);
    return c.json({ message: "Drivers already uploaded this document, so it was switched off instead of deleted." });
  }
  await db.query("delete from app.documents where id = $1 and type = 'driver'", [id]);
  return c.json({ message: "Deleted" });
});

adminDocumentRoutes.put("/admin/driver-rules", ...guard("document edit"), async (c) => {
  const b = await readBody(c);
  const age = Number(b.min_age), years = Number(b.min_licence_years);
  if (!Number.isInteger(age) || age < 16 || age > 80) return validationFailed(c, { min_age: ["Enter an age between 16 and 80."] });
  if (!Number.isFinite(years) || years < 0 || years > 50) return validationFailed(c, { min_licence_years: ["Enter 0 to 50 years."] });
  const db = c.get("db");
  for (const [k, v] of [["driver_min_age", age], ["driver_min_licence_years", years]] as const)
    await db.query("insert into app.settings (key, value) values ($1, $2::jsonb) on conflict (key) do update set value = excluded.value", [k, JSON.stringify(v)]);
  return c.json({ message: "Saved" });
});
