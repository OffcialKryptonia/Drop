import { Hono } from "hono";
import type { Client } from "pg";
import { z } from "zod";
import type { AppEnv } from "../env";
import { withDb } from "../db";
import { requireAuth, USER_COLUMNS } from "../auth/middleware";
import { readBody, validationFailed } from "../lib/legacy";
import { driverModeBlock } from "../lib/roles";
import { serializeUser } from "../serializers/user";

export const modeRoutes = new Hono<AppEnv>();

/** Is this person in the middle of a ride, as a passenger or as a driver? */
async function activeRide(db: Client, userId: number): Promise<{ as: "passenger" | "driver" } | null> {
  const r = (await db.query(
    `select (rider_id = $1) as passenger from app.ride_requests
      where (rider_id = $1 or driver_id = $1) and status in ('searching', 'accepted', 'arrived', 'in_progress') limit 1`, [userId])).rows[0];
  return r ? { as: r.passenger ? "passenger" : "driver" } : null;
}

/**
 * Switch between Passenger mode and Driver mode. Switching to Driver needs an approved driver profile;
 * switching to Passenger is refused during a trip and takes the driver offline.
 */
modeRoutes.post("/mode", withDb, requireAuth, async (c) => {
  const p = z.object({ mode: z.enum(["rider", "driver"], { error: "The mode must be rider or driver." }) }).safeParse(await readBody(c));
  if (!p.success) return validationFailed(c, { mode: [p.error.issues[0].message] });
  const me = c.get("user");
  const db = c.get("db");
  if (me.user_type === "admin" || me.user_type === "fleet") return c.json({ status: false, code: "not_available", message: "Mode switching is for passengers and drivers." }, 403);

  if (p.data.mode === "driver") {
    const block = await driverModeBlock(db, me.id);
    if (block) return c.json({ status: false, ...block }, 403);
    const open = await activeRide(db, me.id);
    if (open) return c.json({ status: false, code: "active_trip", message: open.as === "passenger" ? "You have a ride request open. Cancel it or wait for it to finish, then switch to Driver mode." : "Finish your current trip before switching." }, 409);
  } else if (await activeRide(db, me.id)) {
    return c.json({ status: false, code: "active_trip", message: "Finish your current trip before switching to Passenger mode." }, 409);
  }

  await db.query(
    `update app.users set active_mode = $2, is_online = case when $2 = 'rider' then false else is_online end,
            is_available = case when $2 = 'rider' then false else is_available end where id = $1`,
    [me.id, p.data.mode]);
  const row = (await db.query(`select ${USER_COLUMNS} from app.users u where u.id = $1`, [me.id])).rows[0];
  return c.json({ status: true, data: serializeUser(row) });
});
