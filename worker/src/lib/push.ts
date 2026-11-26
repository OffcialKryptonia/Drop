import type { Client } from "pg";
import type { Bindings } from "../env";
import { getSetting } from "./driver-application";
import { deliverPush, pushConfig, type PushMessage } from "./push-core";
import { notify } from "./push-delivery";
import { notifyEmail } from "./email-delivery";
import { money } from "./push-templates";

export { pushConfig };
export type { PushMessage };

/**
 * Sends a push straight to people's phones through OneSignal, with no template and no delivery log. Used for the
 * Admin "test" button on the Push notifications settings page. Never throws.
 * Everything the apps send in normal use goes through notify() (lib/push-delivery.ts) so Admin can edit and log it.
 */
export async function sendPushDetailed(db: Client, env: Bindings, userIds: number[], msg: PushMessage): Promise<{ sent: number; error?: string }> {
  try {
    if (!userIds.length) return { sent: 0, error: "No one to send to." };
    const ids = (await db.query("select player_id from app.users where id = any($1::bigint[]) and player_id is not null and player_id <> ''", [userIds])).rows.map((r) => String(r.player_id));
    const r = await deliverPush(db, env, ids, msg);
    return { sent: r.sent, error: r.error };
  } catch (e) {
    console.error("push error", (e as Error).message);
    return { sent: 0, error: (e as Error).message };
  }
}

/** Runs a push after the response has gone out, when the platform allows it. */
export function pushLater(c: { executionCtx: { waitUntil(p: Promise<unknown>): void } }, work: Promise<unknown>) {
  try { c.executionCtx.waitUntil(work); } catch { /* the promise still runs */ }
}

/** Tells the online, free drivers near a new request's pickup point (same ride type) that a ride is waiting. */
export async function pushNearbyDrivers(db: Client, env: Bindings, rideId: number): Promise<void> {
  try {
    const radius = await getSetting(db, "nearby_driver_radius_m", 5000);
    const rows = (await db.query(
      `select du.id, r.fare, r.currency, r.pickup_address
         from app.ride_requests r
         join app.driver_profiles p on p.service_id = r.service_id and p.accepts_standard
         join app.users du on du.id = p.user_id
        where r.id = $1 and r.status = 'searching' and du.id <> r.rider_id and du.is_online and du.is_available
          and du.player_id is not null and du.location is not null
          and extensions.st_dwithin(du.location, extensions.st_setsrid(extensions.st_makepoint(r.pickup_lng, r.pickup_lat), 4326)::extensions.geography, $2)
        limit 30`, [rideId, radius])).rows;
    if (!rows.length) return;
    const first = rows[0];
    await notify(db, env, {
      key: "driver.new_ride_request", userIds: rows.map((r) => Number(r.id)), rideId,
      vars: { fare: money(first.fare, first.currency), pickup_location: first.pickup_address ?? "" },
      data: { type: "ride_request", ride_id: String(rideId) },
    });
  } catch (e) { console.error("push nearby drivers", (e as Error).message); }
}

export type RideEvent = "accepted" | "arrived" | "started" | "completed" | "driver_cancelled" | "rider_cancelled";

const RIDE_EVENT_KEY: Record<RideEvent, string> = {
  accepted: "passenger.driver_assigned",
  arrived: "passenger.driver_arrived",
  started: "passenger.ride_started",
  completed: "passenger.ride_completed",
  driver_cancelled: "passenger.ride_cancelled_by_driver",
  rider_cancelled: "driver.ride_cancelled_by_passenger",
};

/** One short push about a ride to the rider (or, for a rider cancellation, to the driver). */
export async function pushRideEvent(db: Client, env: Bindings, userId: number, event: RideEvent, rideId: number, extra?: { fare?: unknown; currency?: unknown }): Promise<void> {
  await notify(db, env, {
    key: RIDE_EVENT_KEY[event], userIds: [userId], rideId,
    vars: extra?.fare != null ? { fare: money(extra.fare, extra.currency) } : undefined,
    data: { type: "ride", event, ride_id: String(rideId) },
  });
}

/** Money arrived in someone's wallet. The driver's and the passenger's wallets have their own templates. */
export async function pushWalletCredit(db: Client, env: Bindings, userId: number, amount: unknown, why: string): Promise<void> {
  try {
    const u = (await db.query("select user_type from app.users where id = $1", [userId])).rows[0];
    const cur = (await db.query("select currency from app.wallets where user_id = $1 order by kind limit 1", [userId]).catch(() => ({ rows: [] as { currency?: string }[] }))).rows[0]?.currency;
    await notify(db, env, {
      key: u?.user_type === "driver" ? "driver.wallet_credited" : "passenger.wallet_credited", userIds: [userId],
      vars: { amount: money(amount, cur), reason: why }, data: { type: "wallet" }, dedupe: null,
    });
    if (u?.user_type !== "driver") await notifyEmail(db, env, { key: "email.passenger.wallet_update", userIds: [userId], vars: { amount: money(amount, cur), reason: why }, dedupe: null });
  } catch (e) { console.error("push wallet credit", (e as Error).message); }
}
