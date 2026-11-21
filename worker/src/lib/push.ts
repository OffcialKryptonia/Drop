import type { Client } from "pg";
import type { Bindings } from "../env";
import { decryptValue } from "./crypto";
import { getSetting } from "./driver-application";
import { currencyInfo } from "./currency";

const setting = async (db: Client, key: string): Promise<string | null> => {
  const v = (await db.query("select value #>> '{}' as v from app.settings where key = $1", [key])).rows[0]?.v;
  return typeof v === "string" && v ? v : null;
};

/** The OneSignal app id (public: the apps read it) and the REST key (secret, stored encrypted). */
export async function pushConfig(db: Client, env: Bindings): Promise<{ appId: string | null; restKey: string | null }> {
  const appId = await setting(db, "push_app_id");
  const enc = await setting(db, "push_rest_key_enc");
  let restKey: string | null = null;
  if (enc) {
    try { restKey = await decryptValue(enc, env.SETTINGS_ENCRYPTION_KEY); } catch { restKey = null; }
  }
  return { appId, restKey };
}

export type PushMessage = { title: string; body: string; data?: Record<string, string> };

/**
 * Sends a push notification to people's phones through OneSignal. Never throws: a push that cannot be sent
 * (not set up yet, no device registered, OneSignal down) must never break the action that caused it.
 * Returns how many devices it was sent to.
 */
export async function sendPushDetailed(db: Client, env: Bindings, userIds: number[], msg: PushMessage): Promise<{ sent: number; error?: string }> {
  try {
    if (!userIds.length) return { sent: 0, error: "No one to send to." };
    const { appId, restKey } = await pushConfig(db, env);
    if (!appId || !restKey) return { sent: 0, error: "Push is not set up yet." };
    const ids = (await db.query("select player_id from app.users where id = any($1::bigint[]) and player_id is not null and player_id <> ''", [userIds])).rows.map((r) => String(r.player_id));
    if (!ids.length) return { sent: 0, error: "No phone is registered for that person." };
    const res = await fetch("https://api.onesignal.com/notifications?c=push", {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Key ${restKey}` },
      body: JSON.stringify({ app_id: appId, target_channel: "push", include_subscription_ids: ids, headings: { en: msg.title }, contents: { en: msg.body }, data: msg.data ?? {} }),
    });
    const text = await res.text();
    let json: { id?: string; errors?: unknown } = {};
    try { json = JSON.parse(text); } catch { /* not json */ }
    // OneSignal can answer 200 with an error list and no notification id: that is a failure, not a send.
    if (!res.ok || !json.id) {
      const why = json.errors ? JSON.stringify(json.errors) : text;
      console.error("push failed", res.status, why.slice(0, 300));
      return { sent: 0, error: `OneSignal said: ${why.slice(0, 200)}` };
    }
    return { sent: ids.length };
  } catch (e) {
    console.error("push error", (e as Error).message);
    return { sent: 0, error: (e as Error).message };
  }
}

export async function sendPush(db: Client, env: Bindings, userIds: number[], msg: PushMessage): Promise<number> {
  return (await sendPushDetailed(db, env, userIds, msg)).sent;
}

/** Runs a push after the response has gone out, when the platform allows it. */
export function pushLater(c: { executionCtx: { waitUntil(p: Promise<unknown>): void } }, work: Promise<unknown>) {
  try { c.executionCtx.waitUntil(work); } catch { /* the promise still runs */ }
}

const money = (amount: unknown, currency: unknown) => {
  const i = currencyInfo(String(currency ?? "NGN").trim() || "NGN");
  return `${i.symbol}${Number(amount).toLocaleString("en-NG", { maximumFractionDigits: 2 })}`;
};

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
    await sendPush(db, env, rows.map((r) => Number(r.id)), {
      title: "New ride request",
      body: `${money(first.fare, first.currency)}${first.pickup_address ? ` · ${String(first.pickup_address).slice(0, 80)}` : ""}`,
      data: { type: "ride_request", ride_id: String(rideId) },
    });
  } catch (e) { console.error("push nearby drivers", (e as Error).message); }
}

export type RideEvent = "accepted" | "arrived" | "started" | "completed" | "driver_cancelled" | "rider_cancelled";

/** One short push about a ride to the rider (or, for a rider cancellation, to the driver). */
export async function pushRideEvent(db: Client, env: Bindings, userId: number, event: RideEvent, rideId: number, extra?: { fare?: unknown; currency?: unknown }): Promise<void> {
  const text: Record<RideEvent, [string, string]> = {
    accepted: ["Driver on the way", "A driver accepted your ride and is heading to you."],
    arrived: ["Your driver has arrived", "Your driver is at the pickup point."],
    started: ["Trip started", "Enjoy your ride."],
    completed: ["Trip completed", extra?.fare != null ? `Fare ${money(extra.fare, extra.currency)}. Thanks for riding with DROP.` : "Thanks for riding with DROP."],
    driver_cancelled: ["Driver cancelled", "Your driver cancelled. We are finding you another driver."],
    rider_cancelled: ["Ride cancelled", "The passenger cancelled this ride."],
  };
  await sendPush(db, env, [userId], { title: text[event][0], body: text[event][1], data: { type: "ride", event, ride_id: String(rideId) } });
}

/** Money arrived in someone's wallet. */
export async function pushWalletCredit(db: Client, env: Bindings, userId: number, amount: unknown, why: string): Promise<void> {
  const cur = (await db.query("select currency from app.wallets where user_id = $1 order by kind limit 1", [userId]).catch(() => ({ rows: [] as { currency?: string }[] }))).rows[0]?.currency;
  await sendPush(db, env, [userId], { title: "Wallet credited", body: `${money(amount, cur)} ${why}`, data: { type: "wallet" } });
}
