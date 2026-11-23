import { Hono, type Context } from "hono";
import { z } from "zod";
import type { AppEnv } from "../env";
import { withDb } from "../db";
import { audit, guard } from "../lib/permissions";
import { readBody, validationFailed } from "../lib/legacy";
import { requireWebOrBearer } from "../auth/web-or-bearer";
import { activeRules } from "../lib/airports";

export const adminAirportRoutes = new Hono<AppEnv>();
export const airportPublicRoutes = new Hono<AppEnv>();
type C = Context<AppEnv>;

const zodErrors = (error: z.ZodError) => {
  const errors: Record<string, string[]> = {};
  for (const i of error.issues) (errors[String(i.path.join(".") || "body")] ??= []).push(i.message);
  return errors;
};
const idParam = (c: C) => {
  const n = Number(c.req.param("id"));
  return Number.isInteger(n) && n > 0 ? n : null;
};
const notFound = (c: C) => c.json({ message: "Not found", status: 404 }, 404);

const point = z.object({ lat: z.coerce.number().min(-90).max(90), lng: z.coerce.number().min(-180).max(180) });
const terminal = z.object({ name: z.string().trim().min(1).max(80), pickup_instructions: z.string().trim().max(500).optional() });

/** Nothing about a real airport is built in: every value here is entered and verified by an admin. */
const airportSchema = z.object({
  region_id: z.coerce.number().int().positive(),
  name: z.string().trim().min(2).max(120),
  iata_code: z.string().trim().toUpperCase().regex(/^[A-Z]{3}$/, "IATA code is 3 letters.").nullable().optional(),
  icao_code: z.string().trim().toUpperCase().regex(/^[A-Z]{4}$/, "ICAO code is 4 letters.").nullable().optional(),
  latitude: z.coerce.number().min(-90).max(90).nullable().optional(),
  longitude: z.coerce.number().min(-180).max(180).nullable().optional(),
  radius_m: z.coerce.number().int().min(100).max(20000).nullable().optional(),
  geofence_coordinates: z.array(point).min(3).max(500).nullable().optional(),
  terminals: z.array(terminal).max(30).default([]),
  pickup_instructions: z.string().trim().max(1000).nullable().optional(),
  default_surcharge: z.coerce.number().min(0).max(1000000).default(0),
  status: z.boolean().default(false),
});

function polygonWkt(points: { lat: number; lng: number }[] | null | undefined): string | null {
  if (!points?.length) return null;
  const ring = points.map((p) => `${p.lng} ${p.lat}`);
  if (ring[0] !== ring[ring.length - 1]) ring.push(ring[0]);
  return `POLYGON((${ring.join(",")}))`;
}

/** An airport can only be switched on once it has a location and a boundary (polygon or radius). */
export function activationProblem(d: z.infer<typeof airportSchema>): string | null {
  if (!d.status) return null;
  if (d.latitude == null || d.longitude == null) return "Set the airport's latitude and longitude before activating it.";
  if (!d.geofence_coordinates?.length && d.radius_m == null) return "Draw a geofence or set a radius before activating the airport.";
  return null;
}

const SELECT = `select a.id, a.region_id, (select name from app.regions r where r.id = a.region_id) as region_name, a.name, a.iata_code, a.icao_code,
  a.latitude, a.longitude, a.radius_m, a.geofence_coordinates, a.terminals, a.pickup_instructions, a.default_surcharge, a.status, a.created_at
  from app.airports a`;

adminAirportRoutes.get("/admin/airports", ...guard("airport list"), async (c) => {
  const r = await c.get("db").query(`${SELECT} where a.deleted_at is null order by a.name, a.id`);
  return c.json({ data: r.rows });
});

async function writeAirport(c: C, id: number | null) {
  const p = airportSchema.safeParse(await readBody(c));
  if (!p.success) return validationFailed(c, zodErrors(p.error));
  const d = p.data;
  const db = c.get("db");
  const bad = activationProblem(d);
  if (bad) return validationFailed(c, { status: [bad] });
  if (!(await db.query("select 1 from app.regions where id = $1", [d.region_id])).rowCount) return validationFailed(c, { region_id: ["Choose a service region."] });
  const hasPoint = d.latitude != null && d.longitude != null;
  const args = [d.region_id, d.name, d.iata_code ?? null, d.icao_code ?? null, d.latitude ?? null, d.longitude ?? null, d.radius_m ?? null,
    polygonWkt(d.geofence_coordinates), d.geofence_coordinates ? JSON.stringify(d.geofence_coordinates) : null, JSON.stringify(d.terminals),
    d.pickup_instructions ?? null, d.default_surcharge, d.status, hasPoint];
  const geo = `case when $14 then extensions.st_setsrid(extensions.st_makepoint($6::float8, $5::float8), 4326)::extensions.geography else null end,
               case when $8::text is null then null else extensions.st_geogfromtext($8) end`;
  try {
    if (id === null) {
      const r = await db.query(
        `insert into app.airports (region_id, name, iata_code, icao_code, latitude, longitude, radius_m, geofence_coordinates, terminals, pickup_instructions, default_surcharge, status, location, geofence)
         values ($1,$2,$3,$4,$5,$6,$7,$9::jsonb,$10::jsonb,$11,$12,$13, ${geo}) returning id`, args);
      await audit(c, "airport_add", String(r.rows[0].id), { name: d.name, iata: d.iata_code ?? null, active: d.status });
      return c.json({ message: "Airport added", id: r.rows[0].id }, 201);
    }
    const r = await db.query(
      `update app.airports set region_id=$1, name=$2, iata_code=$3, icao_code=$4, latitude=$5, longitude=$6, radius_m=$7, geofence_coordinates=$9::jsonb,
              terminals=$10::jsonb, pickup_instructions=$11, default_surcharge=$12, status=$13, updated_at=now(),
              (location, geofence) = (${geo}) where id=$15 and deleted_at is null`, [...args, id]);
    if (!r.rowCount) return notFound(c);
    await audit(c, "airport_edit", String(id), { name: d.name, active: d.status });
    return c.json({ message: "Saved" });
  } catch (e) {
    if ((e as { code?: string }).code === "23505") return validationFailed(c, { iata_code: ["Another airport already uses this IATA code."] });
    throw e;
  }
}

adminAirportRoutes.post("/admin/airports", ...guard("airport add"), (c) => writeAirport(c, null));
adminAirportRoutes.put("/admin/airports/:id", ...guard("airport edit"), async (c) => { const id = idParam(c); return id ? writeAirport(c, id) : notFound(c); });

adminAirportRoutes.delete("/admin/airports/:id", ...guard("airport delete"), async (c) => {
  const id = idParam(c); if (!id) return notFound(c);
  const db = c.get("db");
  if ((await db.query("select 1 from app.ride_requests where airport_id = $1 and status in ('searching','accepted','arrived','in_progress') limit 1", [id])).rowCount)
    return c.json({ message: "This airport has rides in progress.", status: 422 }, 422);
  const r = await db.query("update app.airports set deleted_at = now(), status = false where id = $1 and deleted_at is null", [id]);
  if (!r.rowCount) return notFound(c);
  await audit(c, "airport_delete", String(id));
  return c.json({ message: "Deleted" });
});

const priceSchema = z.object({
  service_id: z.coerce.number().int().positive().nullable().optional(),
  direction: z.enum(["drop", "pickup"]).nullable().optional(),
  mode: z.enum(["fixed", "standard"]),
  fixed_price: z.coerce.number().min(0).max(100000000).nullable().optional(),
  surcharge: z.coerce.number().min(0).max(1000000).default(0),
  status: z.boolean().default(true),
}).refine((v) => v.mode !== "fixed" || v.fixed_price != null, { message: "A fixed-price rule needs a price.", path: ["fixed_price"] });

adminAirportRoutes.get("/admin/airports/:id/prices", ...guard("airport list"), async (c) => {
  const id = idParam(c); if (!id) return notFound(c);
  const r = await c.get("db").query(
    `select p.id, p.service_id, (select name from app.services s where s.id = p.service_id) as service_name, p.direction, p.mode, p.fixed_price, p.surcharge, p.status
       from app.airport_prices p where p.airport_id = $1 order by p.id`, [id]);
  return c.json({ data: r.rows });
});

adminAirportRoutes.post("/admin/airports/:id/prices", ...guard("airport edit"), async (c) => {
  const id = idParam(c); if (!id) return notFound(c);
  const p = priceSchema.safeParse(await readBody(c));
  if (!p.success) return validationFailed(c, zodErrors(p.error));
  const d = p.data, db = c.get("db");
  if (!(await db.query("select 1 from app.airports where id = $1 and deleted_at is null", [id])).rowCount) return notFound(c);
  try {
    const r = await db.query(
      "insert into app.airport_prices (airport_id, service_id, direction, mode, fixed_price, surcharge, status) values ($1,$2,$3,$4,$5,$6,$7) returning id",
      [id, d.service_id ?? null, d.direction ?? null, d.mode, d.mode === "fixed" ? d.fixed_price : null, d.surcharge, d.status]);
    await audit(c, "airport_price_add", String(id), { rule: r.rows[0].id, mode: d.mode, service_id: d.service_id ?? null, direction: d.direction ?? null });
    return c.json({ message: "Price rule added", id: r.rows[0].id }, 201);
  } catch (e) {
    if ((e as { code?: string }).code === "23505") return validationFailed(c, { service_id: ["A rule for this ride type and direction already exists."] });
    throw e;
  }
});

adminAirportRoutes.put("/admin/airport-prices/:id", ...guard("airport edit"), async (c) => {
  const id = idParam(c); if (!id) return notFound(c);
  const p = priceSchema.safeParse(await readBody(c));
  if (!p.success) return validationFailed(c, zodErrors(p.error));
  const d = p.data;
  try {
    const r = await c.get("db").query(
      "update app.airport_prices set service_id=$2, direction=$3, mode=$4, fixed_price=$5, surcharge=$6, status=$7 where id=$1",
      [id, d.service_id ?? null, d.direction ?? null, d.mode, d.mode === "fixed" ? d.fixed_price : null, d.surcharge, d.status]);
    if (!r.rowCount) return notFound(c);
  } catch (e) {
    if ((e as { code?: string }).code === "23505") return validationFailed(c, { service_id: ["A rule for this ride type and direction already exists."] });
    throw e;
  }
  await audit(c, "airport_price_edit", String(id), { mode: d.mode });
  return c.json({ message: "Saved" });
});

adminAirportRoutes.delete("/admin/airport-prices/:id", ...guard("airport delete"), async (c) => {
  const id = idParam(c); if (!id) return notFound(c);
  const r = await c.get("db").query("delete from app.airport_prices where id=$1", [id]);
  if (!r.rowCount) return notFound(c);
  await audit(c, "airport_price_delete", String(id));
  return c.json({ message: "Deleted" });
});

/** Airports the app may offer: active, in an active region. The app never hardcodes airports; this is the only source. */
airportPublicRoutes.get("/airports", withDb, requireWebOrBearer, async (c) => {
  const r = await c.get("db").query(
    `select a.id, a.name, a.iata_code, a.latitude, a.longitude, a.terminals, a.pickup_instructions, a.region_id
       from app.airports a join app.regions g on g.id = a.region_id and g.status
      where a.status and a.deleted_at is null order by a.name`);
  return c.json({ status: true, flight_tracking: false, data: r.rows.map((x) => ({ ...x, id: Number(x.id), region_id: Number(x.region_id), latitude: Number(x.latitude), longitude: Number(x.longitude) })) });
});

export { activeRules };
