import type { Client } from "pg";

type Row = Record<string, unknown>;

/** The vehicle as the older driver screens expect it, built from the application the driver filled in. */
export function vehicleFromProfile(p: Row | undefined) {
  if (!p) return null;
  return {
    car_model: [p.vehicle_make, p.vehicle_model].filter(Boolean).join(" ") || null,
    car_color: (p.vehicle_colour as string) ?? null,
    car_plate_number: (p.vehicle_plate as string) ?? null,
    car_production_year: p.vehicle_year != null ? String(p.vehicle_year) : null,
  };
}

/** A change made on the older "Vehicle details" screen. Keeps the application (what riders see) and user_details in step. */
export async function saveVehicleEdit(db: Client, userId: number, v: { car_model?: string; car_color?: string; car_plate_number?: string; car_production_year?: string }) {
  const profile = (await db.query("select vehicle_make, vehicle_model from app.driver_profiles where user_id = $1", [userId])).rows[0];
  if (profile) {
    const sets: string[] = [], args: unknown[] = [userId];
    const add = (col: string, val: unknown) => { args.push(val); sets.push(`${col} = $${args.length}`); };
    if (v.car_model !== undefined) {
      const current = [profile.vehicle_make, profile.vehicle_model].filter(Boolean).join(" ");
      if (v.car_model !== current) { add("vehicle_make", ""); add("vehicle_model", v.car_model); } // one free-text name on that screen
    }
    if (v.car_color !== undefined) add("vehicle_colour", v.car_color);
    if (v.car_plate_number !== undefined) add("vehicle_plate", v.car_plate_number.toUpperCase());
    if (v.car_production_year !== undefined) add("vehicle_year", v.car_production_year);
    if (sets.length) await db.query(`update app.driver_profiles set ${sets.join(", ")} where user_id = $1`, args);
  }
  await db.query(
    `insert into app.user_details (user_id, car_model, car_color, car_plate_number, car_production_year)
     select $1, $2, $3, $4, $5 where not exists (select 1 from app.user_details where user_id = $1)`,
    [userId, v.car_model ?? null, v.car_color ?? null, v.car_plate_number ?? null, v.car_production_year ?? null]);
  const sets: string[] = [], args: unknown[] = [userId];
  for (const [col, val] of Object.entries(v)) if (val !== undefined) { args.push(val); sets.push(`${col} = $${args.length}`); }
  if (sets.length) await db.query(`update app.user_details set ${sets.join(", ")}, updated_at = now() where user_id = $1`, args);
}
