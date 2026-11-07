import type { Client } from "pg";

export const EDITABLE = ["draft", "needs_changes", "rejected"];

export async function getSetting(db: Client, key: string, fallback: number): Promise<number> {
  const n = Number((await db.query("select value from app.settings where key = $1", [key])).rows[0]?.value);
  return Number.isFinite(n) ? n : fallback;
}

/** Creates the applicant's profile on first use and gives the person the driver role (approval is the profile status). */
export async function ensureProfile(db: Client, userId: number) {
  await db.query("insert into app.driver_profiles (user_id) values ($1) on conflict (user_id) do nothing", [userId]);
  await db.query("update app.users set roles = array_append(roles, 'driver') where id = $1 and not ('driver' = any(roles))", [userId]);
}

/** Active driver documents that apply to a ride type (all of them when none is chosen yet). */
export async function documentsFor(db: Client, driverId: number, serviceId: number | null) {
  return (await db.query(
    `select d.id as document_id, d.name, d.is_required as required, d.has_expiry_date,
            x.id as upload_id, x.expire_date, x.is_verified, x.admin_note, x.uploaded_at, x.content_type, (x.file_key is not null) as uploaded
       from app.documents d
       left join app.driver_documents x on x.document_id = d.id and x.driver_id = $1
      where d.status and d.type = 'driver'
        and (not exists (select 1 from app.document_requirements r where r.document_id = d.id)
             or exists (select 1 from app.document_requirements r where r.document_id = d.id and r.service_id = $2))
      order by d.is_required desc, d.id`, [driverId, serviceId])).rows;
}

/** What is still missing before an application can be submitted. Empty = ready. */
export async function missingForSubmit(db: Client, userId: number, minAge: number, minLicence: number): Promise<string[]> {
  const u = (await db.query("select first_name, last_name, profile_image_key from app.users where id = $1", [userId])).rows[0];
  const p = (await db.query("select * from app.driver_profiles where user_id = $1", [userId])).rows[0];
  const miss: string[] = [];
  if (!u?.first_name || !u?.last_name) miss.push("name");
  if (!u?.profile_image_key) miss.push("photo");
  if (!p) return [...miss, "personal", "vehicle"];
  if (!p.date_of_birth) miss.push("date_of_birth");
  else if (ageOn(String(p.date_of_birth)) < minAge) miss.push("age");
  if (!p.service_id) miss.push("vehicle_type");
  for (const f of ["vehicle_make", "vehicle_model", "vehicle_year", "vehicle_colour", "vehicle_plate", "vehicle_seats"]) if (!p[f]) miss.push(f);
  if (p.licence_years == null || p.licence_years < minLicence) miss.push("licence_years");
  if (p.service_id) {
    for (const d of await documentsFor(db, userId, p.service_id)) {
      if (!d.required) continue;
      if (!d.uploaded) miss.push(`document:${d.document_id}`);
      else if (d.has_expiry_date && (!d.expire_date || new Date(d.expire_date) <= new Date())) miss.push(`document_expiry:${d.document_id}`);
    }
  }
  return miss;
}

/** Whole years between a YYYY-MM-DD date of birth and today. */
export function ageOn(dob: string, today = new Date()): number {
  const [y, m, d] = dob.slice(0, 10).split("-").map(Number);
  let age = today.getUTCFullYear() - y;
  if (today.getUTCMonth() + 1 < m || (today.getUTCMonth() + 1 === m && today.getUTCDate() < d)) age--;
  return age;
}

export const validDate = (v: unknown): v is string => typeof v === "string" && /^\d{4}-\d{2}-\d{2}$/.test(v) && !Number.isNaN(Date.parse(v));
