import { Hono, type Context } from "hono";
import { z } from "zod";
import type { AppEnv } from "../env";
import { UNIQUE_VIOLATION } from "../db";
import { audit, guard, loadAccess, MODULES } from "../lib/permissions";
import { readBody, validationFailed } from "../lib/legacy";
import { hashPassword } from "../auth/password";
import { withDb } from "../db";
import { requireAuth } from "../auth/middleware";
import { STARTER_RIDE_TYPES } from "../lib/starter-ride-types";
import { ALL_PERMISSIONS } from "../lib/permissions";

export const adminCatalogRoutes = new Hono<AppEnv>();
type C = Context<AppEnv>;

function zodErrors(error: z.ZodError) {
  const errors: Record<string, string[]> = {};
  for (const i of error.issues) (errors[String(i.path.join(".") || "body")] ??= []).push(i.message);
  return errors;
}
const idParam = (c: C) => {
  const n = Number(c.req.param("id"));
  return Number.isInteger(n) && n > 0 ? n : null;
};
const notFound = (c: C) => c.json({ message: "Not found", status: 404 }, 404);

/** Builds "col = $n, ..." for a partial update from the keys the caller actually sent. */
function setClause(data: Record<string, unknown>, jsonKeys: string[] = [], start = 1) {
  const keys = Object.keys(data).filter((k) => data[k] !== undefined);
  return {
    keys,
    sql: keys.map((k, i) => `${k} = $${i + start}${jsonKeys.includes(k) ? "::jsonb" : ""}`).join(", "),
    values: keys.map((k) => (jsonKeys.includes(k) && data[k] !== null ? JSON.stringify(data[k]) : data[k])),
  };
}

// ---------------------------------------------------------------------------
// Who am I (drives the admin sidebar)
// ---------------------------------------------------------------------------
adminCatalogRoutes.get("/admin/me", withDb, requireAuth, async (c) => {
  const u = c.get("user");
  if (u.user_type !== "admin") return c.json({ message: "Forbidden" }, 403);
  const access = await loadAccess(c);
  return c.json({
    id: u.id, name: u.display_name ?? `${u.first_name ?? ""} ${u.last_name ?? ""}`.trim(), email: u.email,
    is_super: access.isSuper, permissions: [...access.permissions],
  });
});

// ---------------------------------------------------------------------------
// Regions
// ---------------------------------------------------------------------------
const point = z.object({ lat: z.coerce.number().min(-90).max(90), lng: z.coerce.number().min(-180).max(180) });
const regionSchema = z.object({
  name: z.string().trim().min(1).max(120),
  distance_unit: z.enum(["km", "mile"]),
  timezone: z.string().trim().min(1).max(60),
  status: z.boolean(),
  coordinates: z.array(point).min(3).max(500).nullable(),
});

/** Closed ring in "lng lat" order for PostGIS. */
function polygonWkt(points: { lat: number; lng: number }[] | null): string | null {
  if (!points) return null;
  const ring = points.map((p) => `${p.lng} ${p.lat}`);
  if (ring[0] !== ring[ring.length - 1]) ring.push(ring[0]);
  return `POLYGON((${ring.join(",")}))`;
}

adminCatalogRoutes.get("/admin/regions", ...guard("region list"), async (c) => {
  const r = await c.get("db").query(
    `select r.id, r.name, r.distance_unit, r.timezone, r.status, r.coordinates, r.created_at,
            (select count(*)::int from app.services s where s.region_id = r.id and s.deleted_at is null) as ride_types
       from app.regions r order by r.name nulls last, r.id`);
  return c.json({ data: r.rows });
});

adminCatalogRoutes.post("/admin/regions", ...guard("region add"), async (c) => {
  const p = regionSchema.safeParse(await readBody(c));
  if (!p.success) return validationFailed(c, zodErrors(p.error));
  const d = p.data;
  const r = await c.get("db").query(
    `insert into app.regions (name, distance_unit, timezone, status, coordinates, boundary)
     values ($1,$2,$3,$4,$5::jsonb, case when $6::text is null then null else extensions.st_geogfromtext($6) end) returning id`,
    [d.name, d.distance_unit, d.timezone, d.status, d.coordinates ? JSON.stringify(d.coordinates) : null, polygonWkt(d.coordinates)]);
  await audit(c, "region_add", String(r.rows[0].id), { name: d.name });
  return c.json({ message: "Region added", id: r.rows[0].id }, 201);
});

adminCatalogRoutes.put("/admin/regions/:id", ...guard("region edit"), async (c) => {
  const id = idParam(c); if (!id) return notFound(c);
  const p = regionSchema.safeParse(await readBody(c));
  if (!p.success) return validationFailed(c, zodErrors(p.error));
  const d = p.data;
  const r = await c.get("db").query(
    `update app.regions set name=$2, distance_unit=$3, timezone=$4, status=$5, coordinates=$6::jsonb,
            boundary = case when $7::text is null then null else extensions.st_geogfromtext($7) end where id=$1`,
    [id, d.name, d.distance_unit, d.timezone, d.status, d.coordinates ? JSON.stringify(d.coordinates) : null, polygonWkt(d.coordinates)]);
  if (!r.rowCount) return notFound(c);
  await audit(c, "region_edit", String(id), { name: d.name });
  return c.json({ message: "Saved" });
});

adminCatalogRoutes.delete("/admin/regions/:id", ...guard("region delete"), async (c) => {
  const id = idParam(c); if (!id) return notFound(c);
  const db = c.get("db");
  const used = (await db.query("select count(*)::int n from app.services where region_id=$1 and deleted_at is null", [id])).rows[0].n;
  if (used) return c.json({ message: "This region still has ride types. Delete or move them first.", status: 422 }, 422);
  const r = await db.query("delete from app.regions where id=$1", [id]);
  if (!r.rowCount) return notFound(c);
  await audit(c, "region_delete", String(id));
  return c.json({ message: "Deleted" });
});

// ---------------------------------------------------------------------------
// Ride types (app.services)
// ---------------------------------------------------------------------------
const money = z.coerce.number().min(0).max(100_000_000);
const i18n = z.record(z.string().min(2).max(10), z.string().max(200));
const BOOKING = ["now", "scheduled", "multi_drop", "bidding", "for_other"] as const;
const PAYMENTS = ["cash", "wallet", "card", "virtual_account"] as const;

const serviceSchema = z.object({
  name: z.string().trim().min(1).max(80),
  region_id: z.coerce.number().int().positive(),
  category: z.string().trim().min(1).max(30).transform((s) => s.toLowerCase()),
  capacity: z.coerce.number().int().min(1).max(100),
  description: z.string().trim().max(500).nullable(),
  icon_url: z.string().trim().max(500).nullable(),
  photo_url: z.string().trim().max(500).nullable(),
  name_i18n: i18n,
  description_i18n: i18n,
  base_fare: money, minimum_fare: money, minimum_distance: money, per_distance: money,
  per_minute_drive: money, per_minute_wait: money, waiting_time_limit: money, cancellation_fee: money,
  commission_type: z.enum(["fixed", "percentage"]),
  admin_commission: money, fleet_commission: money,
  booking_modes: z.array(z.enum(BOOKING)).min(1),
  payment_methods: z.array(z.enum(PAYMENTS)).min(1),
  min_driver_rating: z.coerce.number().min(0).max(5).nullable(),
  min_wallet_balance: z.coerce.number().nullable(),
  working_hours: z.object({ from: z.string().regex(/^\d{2}:\d{2}$/), to: z.string().regex(/^\d{2}:\d{2}$/) }).nullable(),
  badge: z.string().trim().max(20).nullable(),
  sort_order: z.coerce.number().int().min(0).max(10000),
  status: z.boolean(),
});
const SERVICE_JSON = ["name_i18n", "description_i18n", "working_hours"];

/** The shipped apps only know cash / wallet / cash_wallet, so keep that legacy column in step. */
function legacyPayment(methods: string[]) {
  const cash = methods.includes("cash");
  const digital = methods.some((m) => m !== "cash");
  return cash && digital ? "cash_wallet" : cash ? "cash" : "wallet";
}

const SERVICE_COLS = `id, name, region_id, category, capacity, description, icon_url, photo_url, name_i18n, description_i18n,
  base_fare, minimum_fare, minimum_distance, per_distance, per_minute_drive, per_minute_wait, waiting_time_limit,
  cancellation_fee, commission_type, admin_commission, fleet_commission, booking_modes, payment_methods,
  min_driver_rating, min_wallet_balance, working_hours, badge, sort_order, status, created_at, updated_at`;

adminCatalogRoutes.get("/admin/services", ...guard("service list"), async (c) => {
  const region = Number(c.req.query("region_id"));
  const r = await c.get("db").query(
    `select ${SERVICE_COLS}, (select name from app.regions g where g.id = s.region_id) as region_name
       from app.services s where s.deleted_at is null ${region ? "and s.region_id = $1" : ""}
      order by s.sort_order, s.id`, region ? [region] : []);
  return c.json({ data: r.rows });
});

adminCatalogRoutes.get("/admin/services/:id", ...guard("service list"), async (c) => {
  const id = idParam(c); if (!id) return notFound(c);
  const r = await c.get("db").query(`select ${SERVICE_COLS} from app.services s where id=$1 and deleted_at is null`, [id]);
  return r.rows[0] ? c.json({ data: r.rows[0] }) : notFound(c);
});

adminCatalogRoutes.post("/admin/services", ...guard("service add"), async (c) => {
  const p = serviceSchema.safeParse(await readBody(c));
  if (!p.success) return validationFailed(c, zodErrors(p.error));
  const d = p.data;
  const db = c.get("db");
  if (!(await db.query("select 1 from app.regions where id=$1", [d.region_id])).rowCount) {
    return validationFailed(c, { region_id: ["That region does not exist."] });
  }
  const row = { ...d, payment_method: legacyPayment(d.payment_methods) };
  const cols = Object.keys(row);
  const r = await db.query(
    `insert into app.services (${cols.join(",")}) values (${cols.map((k, i) => `$${i + 1}${SERVICE_JSON.includes(k) ? "::jsonb" : ""}`).join(",")}) returning id`,
    cols.map((k) => (SERVICE_JSON.includes(k) && (row as Record<string, unknown>)[k] !== null ? JSON.stringify((row as Record<string, unknown>)[k]) : (row as Record<string, unknown>)[k])));
  await audit(c, "service_add", String(r.rows[0].id), { name: d.name, region_id: d.region_id });
  return c.json({ message: "Ride type added", id: r.rows[0].id }, 201);
});

adminCatalogRoutes.put("/admin/services/:id", ...guard("service edit"), async (c) => {
  const id = idParam(c); if (!id) return notFound(c);
  const p = serviceSchema.partial().safeParse(await readBody(c));
  if (!p.success) return validationFailed(c, zodErrors(p.error));
  const data: Record<string, unknown> = { ...p.data };
  if (p.data.payment_methods) data.payment_method = legacyPayment(p.data.payment_methods);
  const set = setClause(data, SERVICE_JSON, 2);
  if (!set.keys.length) return validationFailed(c, { body: ["Nothing to update."] });
  const r = await c.get("db").query(`update app.services set ${set.sql} where id=$1 and deleted_at is null`, [id, ...set.values]);
  if (!r.rowCount) return notFound(c);
  await audit(c, "service_edit", String(id), { fields: set.keys });
  return c.json({ message: "Saved" });
});

/** Switch on/off quickly from the list. */
adminCatalogRoutes.put("/admin/services/:id/status", ...guard("service edit"), async (c) => {
  const id = idParam(c); if (!id) return notFound(c);
  const p = z.object({ status: z.boolean() }).safeParse(await readBody(c));
  if (!p.success) return validationFailed(c, zodErrors(p.error));
  const r = await c.get("db").query("update app.services set status=$2 where id=$1 and deleted_at is null", [id, p.data.status]);
  if (!r.rowCount) return notFound(c);
  await audit(c, "service_status", String(id), { status: p.data.status });
  return c.json({ message: "Saved" });
});

/** Drag-and-drop order: ids in the order they should appear. */
adminCatalogRoutes.put("/admin/services-order", ...guard("service edit"), async (c) => {
  const p = z.object({ ids: z.array(z.coerce.number().int().positive()).min(1).max(500) }).safeParse(await readBody(c));
  if (!p.success) return validationFailed(c, zodErrors(p.error));
  await c.get("db").query(
    "update app.services s set sort_order = o.ord from (select id, ord - 1 as ord from unnest($1::bigint[]) with ordinality as t(id, ord)) o where s.id = o.id",
    [p.data.ids]);
  await audit(c, "service_reorder", "services", { count: p.data.ids.length });
  return c.json({ message: "Saved" });
});

/** Copy a ride type (fares and all) into another region, switched off. */
adminCatalogRoutes.post("/admin/services/:id/duplicate", ...guard("service add"), async (c) => {
  const id = idParam(c); if (!id) return notFound(c);
  const p = z.object({ region_id: z.coerce.number().int().positive() }).safeParse(await readBody(c));
  if (!p.success) return validationFailed(c, zodErrors(p.error));
  const db = c.get("db");
  if (!(await db.query("select 1 from app.regions where id=$1", [p.data.region_id])).rowCount) {
    return validationFailed(c, { region_id: ["That region does not exist."] });
  }
  const r = await db.query(
    `insert into app.services (name, region_id, category, capacity, description, icon_url, photo_url, name_i18n, description_i18n,
        base_fare, minimum_fare, minimum_distance, per_distance, per_minute_drive, per_minute_wait, waiting_time_limit,
        cancellation_fee, commission_type, admin_commission, fleet_commission, booking_modes, payment_methods, payment_method,
        min_driver_rating, min_wallet_balance, working_hours, badge, sort_order, status)
     select name, $2, category, capacity, description, icon_url, photo_url, name_i18n, description_i18n,
        base_fare, minimum_fare, minimum_distance, per_distance, per_minute_drive, per_minute_wait, waiting_time_limit,
        cancellation_fee, commission_type, admin_commission, fleet_commission, booking_modes, payment_methods, payment_method,
        min_driver_rating, min_wallet_balance, working_hours, badge, sort_order, false
       from app.services where id=$1 and deleted_at is null returning id`, [id, p.data.region_id]);
  if (!r.rowCount) return notFound(c);
  await audit(c, "service_duplicate", String(id), { to_region: p.data.region_id, new_id: r.rows[0].id });
  return c.json({ message: "Copied (switched off)", id: r.rows[0].id }, 201);
});

/** Adds the starter set to a region, all switched off until the admin reviews the fares. */
adminCatalogRoutes.post("/admin/regions/:id/starter-ride-types", ...guard("service add"), async (c) => {
  const id = idParam(c); if (!id) return notFound(c);
  const db = c.get("db");
  if (!(await db.query("select 1 from app.regions where id=$1", [id])).rowCount) return notFound(c);
  const existing = new Set((await db.query("select name from app.services where region_id=$1 and deleted_at is null", [id])).rows.map((r) => r.name));
  const next = (await db.query("select coalesce(max(sort_order),0)::int + 1 as n from app.services where region_id=$1", [id])).rows[0].n;
  let added = 0;
  for (const t of STARTER_RIDE_TYPES) {
    if (existing.has(t.name)) continue;
    await db.query(
      `insert into app.services (name, region_id, category, capacity, description, base_fare, minimum_fare, per_distance, per_minute_drive,
          minimum_distance, per_minute_wait, waiting_time_limit, cancellation_fee, commission_type, admin_commission, payment_method, sort_order, status)
       values ($1,$2,$3,$4,$5,$6,$7,$8,$9, 1, 5, 3, 200, 'percentage', 15, 'cash_wallet', $10, false)`,
      [t.name, id, t.category, t.capacity, t.description, t.base_fare, t.minimum_fare, t.per_distance, t.per_minute_drive, next + added]);
    added++;
  }
  await audit(c, "service_seed", String(id), { added });
  return c.json({ message: added ? `${added} ride types added (switched off). Review the fares, then switch them on.` : "Nothing to add: all starter types already exist.", added });
});

adminCatalogRoutes.delete("/admin/services/:id", ...guard("service delete"), async (c) => {
  const id = idParam(c); if (!id) return notFound(c);
  const db = c.get("db");
  const inUse = (await db.query(
    `select (select count(*) from app.users where service_id=$1) + (select count(*) from app.driver_services where service_id=$1) as n`, [id])).rows[0].n;
  const hasRides = (await db.query("select to_regclass('app.ride_requests') is not null as t")).rows[0].t
    ? Number((await db.query("select count(*) n from app.ride_requests where service_id=$1", [id])).rows[0].n) : 0;
  if (Number(inUse) + hasRides > 0) {
    return c.json({ message: "This ride type has drivers or trips. Switch it off instead of deleting it.", status: 422 }, 422);
  }
  const r = await db.query("update app.services set deleted_at = now(), status = false where id=$1 and deleted_at is null", [id]);
  if (!r.rowCount) return notFound(c);
  await audit(c, "service_delete", String(id));
  return c.json({ message: "Deleted" });
});

// ---------------------------------------------------------------------------
// Ride options (child seat, luggage...)
// ---------------------------------------------------------------------------
const optionSchema = z.object({
  name: z.string().trim().min(1).max(60), name_i18n: i18n, price: money,
  status: z.boolean(), sort_order: z.coerce.number().int().min(0).max(10000),
});
const OPTION_COLS = "id, name, name_i18n, price, status, sort_order";

adminCatalogRoutes.get("/admin/service-options", ...guard("service_option list"), async (c) => {
  const r = await c.get("db").query(`select ${OPTION_COLS} from app.service_options where deleted_at is null order by sort_order, id`);
  return c.json({ data: r.rows });
});
adminCatalogRoutes.post("/admin/service-options", ...guard("service_option add"), async (c) => {
  const p = optionSchema.partial({ name_i18n: true, status: true, sort_order: true, price: true }).safeParse(await readBody(c));
  if (!p.success) return validationFailed(c, zodErrors(p.error));
  const d = p.data;
  const r = await c.get("db").query(
    "insert into app.service_options (name, name_i18n, price, status, sort_order) values ($1,$2::jsonb,$3,$4,$5) returning id",
    [d.name, JSON.stringify(d.name_i18n ?? {}), d.price ?? 0, d.status ?? true, d.sort_order ?? 0]);
  await audit(c, "service_option_add", String(r.rows[0].id), { name: d.name });
  return c.json({ message: "Option added", id: r.rows[0].id }, 201);
});
adminCatalogRoutes.put("/admin/service-options/:id", ...guard("service_option edit"), async (c) => {
  const id = idParam(c); if (!id) return notFound(c);
  const p = optionSchema.partial().safeParse(await readBody(c));
  if (!p.success) return validationFailed(c, zodErrors(p.error));
  const set = setClause(p.data, ["name_i18n"], 2);
  if (!set.keys.length) return validationFailed(c, { body: ["Nothing to update."] });
  const r = await c.get("db").query(`update app.service_options set ${set.sql} where id=$1 and deleted_at is null`, [id, ...set.values]);
  if (!r.rowCount) return notFound(c);
  await audit(c, "service_option_edit", String(id), { fields: set.keys });
  return c.json({ message: "Saved" });
});
adminCatalogRoutes.delete("/admin/service-options/:id", ...guard("service_option delete"), async (c) => {
  const id = idParam(c); if (!id) return notFound(c);
  const r = await c.get("db").query("update app.service_options set deleted_at = now(), status = false where id=$1 and deleted_at is null", [id]);
  if (!r.rowCount) return notFound(c);
  await audit(c, "service_option_delete", String(id));
  return c.json({ message: "Deleted" });
});

// ---------------------------------------------------------------------------
// Roles and sub-admins
// ---------------------------------------------------------------------------
adminCatalogRoutes.get("/admin/permissions", ...guard("role list"), (c) => c.json({ data: MODULES }));

const roleSchema = z.object({
  name: z.string().trim().toLowerCase().regex(/^[a-z0-9_-]{2,40}$/, "Use 2-40 letters, numbers, dash or underscore."),
  label: z.string().trim().min(1).max(60),
  permissions: z.array(z.string()).max(200),
});

adminCatalogRoutes.get("/admin/roles", ...guard("role list"), async (c) => {
  const r = await c.get("db").query(
    `select r.id, r.name, r.label, r.is_super,
            coalesce(array_agg(p.permission order by p.permission) filter (where p.permission is not null), '{}') as permissions,
            (select count(*)::int from app.users u where u.admin_role_id = r.id and u.deleted_at is null) as members
       from app.admin_roles r left join app.admin_role_permissions p on p.role_id = r.id
      group by r.id order by r.is_super desc, r.label`);
  return c.json({ data: r.rows });
});

async function saveRole(c: C, id: number | null) {
  const p = roleSchema.safeParse(await readBody(c));
  if (!p.success) return validationFailed(c, zodErrors(p.error));
  const d = p.data;
  const bad = d.permissions.filter((x) => !ALL_PERMISSIONS.includes(x));
  if (bad.length) return validationFailed(c, { permissions: [`Unknown permission: ${bad[0]}`] });
  const db = c.get("db");
  try {
    await db.query("begin");
    if (id) {
      const cur = (await db.query("select is_super from app.admin_roles where id=$1", [id])).rows[0];
      if (!cur) { await db.query("rollback"); return notFound(c); }
      if (cur.is_super) { await db.query("rollback"); return c.json({ message: "The super admin role cannot be changed.", status: 422 }, 422); }
      await db.query("update app.admin_roles set name=$2, label=$3 where id=$1", [id, d.name, d.label]);
    } else {
      id = (await db.query("insert into app.admin_roles (name, label) values ($1,$2) returning id", [d.name, d.label])).rows[0].id as number;
    }
    await db.query("delete from app.admin_role_permissions where role_id=$1", [id]);
    if (d.permissions.length) {
      await db.query("insert into app.admin_role_permissions (role_id, permission) select $1, unnest($2::text[])", [id, d.permissions]);
    }
    await audit(c, "role_save", String(id), { name: d.name, permissions: d.permissions.length });
    await db.query("commit");
  } catch (err) {
    await db.query("rollback").catch(() => undefined);
    if ((err as { code?: string }).code === UNIQUE_VIOLATION) return validationFailed(c, { name: ["A role with that name already exists."] });
    throw err;
  }
  return c.json({ message: "Saved", id });
}
adminCatalogRoutes.post("/admin/roles", ...guard("role add"), (c) => saveRole(c, null));
adminCatalogRoutes.put("/admin/roles/:id", ...guard("role edit"), (c) => {
  const id = idParam(c); return id ? saveRole(c, id) : notFound(c);
});
adminCatalogRoutes.delete("/admin/roles/:id", ...guard("role delete"), async (c) => {
  const id = idParam(c); if (!id) return notFound(c);
  const db = c.get("db");
  const role = (await db.query("select is_super from app.admin_roles where id=$1", [id])).rows[0];
  if (!role) return notFound(c);
  if (role.is_super) return c.json({ message: "The super admin role cannot be deleted.", status: 422 }, 422);
  const n = (await db.query("select count(*)::int n from app.users where admin_role_id=$1 and deleted_at is null", [id])).rows[0].n;
  if (n) return c.json({ message: "Some sub-admins still use this role. Move them first.", status: 422 }, 422);
  await db.query("delete from app.admin_roles where id=$1", [id]);
  await audit(c, "role_delete", String(id));
  return c.json({ message: "Deleted" });
});

const subAdminSchema = z.object({
  first_name: z.string().trim().min(1).max(100), last_name: z.string().trim().min(1).max(100),
  email: z.string().trim().toLowerCase().email(), username: z.string().trim().min(3).max(100),
  contact_number: z.string().trim().max(30).nullable(),
  admin_role_id: z.coerce.number().int().positive(),
  status: z.enum(["active", "inactive"]),
  password: z.string().min(10).max(72),
});

adminCatalogRoutes.get("/admin/sub-admins", ...guard("subadmin list"), async (c) => {
  const r = await c.get("db").query(
    `select u.id, u.first_name, u.last_name, u.email, u.username, u.contact_number, u.status, u.admin_role_id, r.label as role_label, r.is_super
       from app.users u left join app.admin_roles r on r.id = u.admin_role_id
      where u.user_type='admin' and u.deleted_at is null order by u.id`);
  return c.json({ data: r.rows });
});

adminCatalogRoutes.post("/admin/sub-admins", ...guard("subadmin add"), async (c) => {
  const p = subAdminSchema.safeParse(await readBody(c));
  if (!p.success) return validationFailed(c, zodErrors(p.error));
  const d = p.data;
  const db = c.get("db");
  if (!(await db.query("select 1 from app.admin_roles where id=$1", [d.admin_role_id])).rowCount) {
    return validationFailed(c, { admin_role_id: ["That role does not exist."] });
  }
  try {
    const r = await db.query(
      `insert into app.users (first_name, last_name, display_name, email, username, contact_number, password_hash, login_type, user_type, status, admin_role_id)
       values ($1,$2,$3,$4,$5,$6,$7,'app','admin',$8,$9) returning id`,
      [d.first_name, d.last_name, `${d.first_name} ${d.last_name}`, d.email, d.username, d.contact_number, await hashPassword(db, d.password), d.status, d.admin_role_id]);
    await audit(c, "subadmin_add", String(r.rows[0].id), { email: d.email, role: d.admin_role_id });
    return c.json({ message: "Sub-admin added", id: r.rows[0].id }, 201);
  } catch (err) {
    if ((err as { code?: string }).code === UNIQUE_VIOLATION) return validationFailed(c, { email: ["That email or username is already taken."] });
    throw err;
  }
});

adminCatalogRoutes.put("/admin/sub-admins/:id", ...guard("subadmin edit"), async (c) => {
  const id = idParam(c); if (!id) return notFound(c);
  const p = subAdminSchema.partial().safeParse(await readBody(c));
  if (!p.success) return validationFailed(c, zodErrors(p.error));
  const db = c.get("db");
  const me = c.get("user");
  const target = (await db.query(
    "select u.id, r.is_super from app.users u left join app.admin_roles r on r.id=u.admin_role_id where u.id=$1 and u.user_type='admin' and u.deleted_at is null", [id])).rows[0];
  if (!target) return notFound(c);
  const demoting = p.data.admin_role_id !== undefined || p.data.status === "inactive";
  if (target.is_super && demoting) {
    const supers = (await db.query(
      "select count(*)::int n from app.users u join app.admin_roles r on r.id=u.admin_role_id where r.is_super and u.status='active' and u.deleted_at is null")).rows[0].n;
    if (supers <= 1) return c.json({ message: "You need at least one active super admin.", status: 422 }, 422);
  }
  if (id === me.id && p.data.status === "inactive") return c.json({ message: "You cannot switch off your own account.", status: 422 }, 422);
  const { password, ...rest } = p.data;
  const data: Record<string, unknown> = { ...rest };
  if (password) data.password_hash = await hashPassword(db, password);
  if (rest.first_name || rest.last_name) {
    const cur = (await db.query("select first_name, last_name from app.users where id=$1", [id])).rows[0];
    data.display_name = `${rest.first_name ?? cur.first_name} ${rest.last_name ?? cur.last_name}`;
  }
  const set = setClause(data, [], 2);
  if (!set.keys.length) return validationFailed(c, { body: ["Nothing to update."] });
  try {
    await db.query(`update app.users set ${set.sql} where id=$1`, [id, ...set.values]);
  } catch (err) {
    if ((err as { code?: string }).code === UNIQUE_VIOLATION) return validationFailed(c, { email: ["That email or username is already taken."] });
    throw err;
  }
  if (password || p.data.status === "inactive") await db.query("delete from app.api_tokens where user_id=$1", [id]);
  await audit(c, "subadmin_edit", String(id), { fields: set.keys.filter((k) => k !== "password_hash") });
  return c.json({ message: "Saved" });
});

adminCatalogRoutes.delete("/admin/sub-admins/:id", ...guard("subadmin delete"), async (c) => {
  const id = idParam(c); if (!id) return notFound(c);
  const db = c.get("db");
  if (id === c.get("user").id) return c.json({ message: "You cannot delete your own account.", status: 422 }, 422);
  const target = (await db.query(
    "select r.is_super from app.users u left join app.admin_roles r on r.id=u.admin_role_id where u.id=$1 and u.user_type='admin' and u.deleted_at is null", [id])).rows[0];
  if (!target) return notFound(c);
  if (target.is_super) {
    const supers = (await db.query(
      "select count(*)::int n from app.users u join app.admin_roles r on r.id=u.admin_role_id where r.is_super and u.status='active' and u.deleted_at is null")).rows[0].n;
    if (supers <= 1) return c.json({ message: "You need at least one active super admin.", status: 422 }, 422);
  }
  await db.query("update app.users set deleted_at = now(), status='inactive' where id=$1", [id]);
  await db.query("delete from app.api_tokens where user_id=$1", [id]);
  await audit(c, "subadmin_delete", String(id));
  return c.json({ message: "Deleted" });
});
