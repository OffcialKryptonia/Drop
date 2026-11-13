import { vehicleFromProfile } from "../lib/driver-vehicle";
import { Hono } from "hono";
import type { AppEnv } from "../env";
import { withDb } from "../db";
import { requireAuth, USER_COLUMNS } from "../auth/middleware";
import { MESSAGES } from "../lib/legacy";
import {
  serializeBankAccount, serializeDocument, serializePublicUser, serializeService, serializeUser, serializeUserDetail,
} from "../serializers/user";

export const userRoutes = new Hono<AppEnv>();

userRoutes.get("/user-detail", withDb, requireAuth, async (c) => {
  const me = c.get("user");
  const requested = c.req.query("id");
  const id = requested === undefined ? me.id : /^\d{1,15}$/.test(requested) ? Number(requested) : NaN;
  if (Number.isNaN(id)) return c.json({ message: MESSAGES.userNotFound }, 400);

  const db = c.get("db");
  const found = await db.query(`select ${USER_COLUMNS} from app.users u where u.id = $1 and u.deleted_at is null`, [id]);
  const u = found.rows[0];
  if (!u) return c.json({ message: MESSAGES.userNotFound }, 400);

  const full = me.id === u.id || me.user_type === "admin";
  const detail = await db.query("select * from app.user_details where user_id = $1 limit 1", [id]);
  const data: Record<string, unknown> = {
    ...(full ? serializeUser(u) : serializePublicUser(u)),
    user_detail: serializeUserDetail(detail.rows[0]),
    rating: 0, // ratings arrive with the rides slice
  };

  // Drivers who applied through "Become a driver" keep their vehicle in the application; show it here too.
  const prof = (await db.query("select service_id, vehicle_make, vehicle_model, vehicle_year, vehicle_colour, vehicle_plate from app.driver_profiles where user_id = $1", [id])).rows[0];
  if (prof) {
    const v = vehicleFromProfile(prof)!;
    const have = (data.user_detail ?? {}) as Record<string, unknown>;
    data.user_detail = { ...(serializeUserDetail({ id: 0, user_id: id }) as object), ...have,
      car_model: have.car_model || v.car_model, car_color: have.car_color || v.car_color,
      car_plate_number: have.car_plate_number || v.car_plate_number, car_production_year: have.car_production_year || v.car_production_year };
  }
  if (u.user_type === "driver" || prof) {
    const serviceId = u.service_id ?? prof?.service_id;
    const svc = serviceId
      ? await db.query("select * from app.services where id = $1", [serviceId])
      : { rows: [] };
    data.driver_service = serializeService(svc.rows[0]);
  }
  if (full) {
    const bank = await db.query("select * from app.user_bank_accounts where user_id = $1 limit 1", [id]);
    data.user_bank_account = serializeBankAccount(bank.rows[0]);
    if (u.user_type === "driver") {
      const missing = await db.query(
        `select d.* from app.documents d
          where d.is_required and d.status and d.type = 'driver'
            and not exists (select 1 from app.driver_documents dd where dd.document_id = d.id and dd.driver_id = $1)
          order by d.id`,
        [id],
      );
      data.required_document = missing.rows.map(serializeDocument);
    }
  }
  return c.json({ data });
});
