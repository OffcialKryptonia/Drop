import type { Client } from "pg";

/** The same ride type in another region: same name first, else same category. Null when the region has none. */
export async function equivalentService(db: Client, serviceId: number, regionId: number): Promise<{ id: number; name: string } | null> {
  const r = (await db.query(
    `select t.id, t.name from app.services s
       join app.services t on t.region_id = $2 and t.deleted_at is null and t.status and (lower(t.name) = lower(s.name) or t.category = s.category)
      where s.id = $1
      order by (lower(t.name) = lower(s.name)) desc, t.sort_order, t.id limit 1`, [serviceId, regionId])).rows[0];
  return r ? { id: Number(r.id), name: r.name } : null;
}

/** Checks a drawn border: at least 3 distinct points and a shape that does not cross itself. Returns a message or null. */
export async function borderProblem(db: Client, points: { lat: number; lng: number }[] | null): Promise<string | null> {
  if (!points) return null;
  const distinct = new Set(points.map((p) => `${p.lat.toFixed(6)},${p.lng.toFixed(6)}`));
  if (distinct.size < 3) return "Draw at least 3 different points.";
  const ring = points.map((p) => `${p.lng} ${p.lat}`);
  if (ring[0] !== ring[ring.length - 1]) ring.push(ring[0]);
  const r = (await db.query("select extensions.st_isvalid(extensions.st_geomfromtext($1, 4326)) as ok", [`POLYGON((${ring.join(",")}))`])).rows[0];
  return r?.ok ? null : "The border crosses itself. Move a point so the lines do not cross.";
}
