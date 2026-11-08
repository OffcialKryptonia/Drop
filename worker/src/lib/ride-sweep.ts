import type { Client } from "pg";
import { getSetting } from "./driver-application";

/**
 * Runs every minute (cron trigger):
 * - requests nobody accepted in time become 'expired'
 * - drivers whose app stopped reporting a location (closed, no signal) go offline, unless they are on a ride
 */
export async function sweepRides(db: Client) {
  const expired = await db.query("update app.ride_requests set status = 'expired' where status = 'searching' and expires_at < now()");
  const staleMinutes = await getSetting(db, "driver_location_stale_minutes", 10);
  const offline = await db.query(
    `update app.users u set is_online = false, is_available = false
      where u.is_online and (u.last_location_update_at is null or u.last_location_update_at < now() - make_interval(mins => $1::int))
        and not exists (select 1 from app.ride_requests r where r.driver_id = u.id and r.status in ('accepted', 'arrived', 'in_progress'))`,
    [staleMinutes],
  );
  return { expired: expired.rowCount ?? 0, drivers_offline: offline.rowCount ?? 0 };
}
