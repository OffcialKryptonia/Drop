import type { Client } from "pg";
import { decryptValue, encryptValue } from "./crypto";

/**
 * Pickup code: the passenger shows a 4-digit code, the driver types it, and only then can the trip start.
 * Everything is decided here on the server. The code is never put in a push notification or a driver response.
 */

export type PickupSettings = { enabled: boolean; expiry_minutes: number; max_attempts: number; lock_minutes: number };

export async function pickupSettings(db: Client): Promise<PickupSettings> {
  const v = ((await db.query("select value from app.settings where key = 'pickup_code'")).rows[0]?.value ?? {}) as Record<string, unknown>;
  const num = (x: unknown, d: number, min: number, max: number) => {
    const n = Number(x);
    return Number.isFinite(n) ? Math.min(max, Math.max(min, Math.round(n))) : d;
  };
  return {
    enabled: v.enabled !== false,
    expiry_minutes: num(v.expiry_minutes, 180, 10, 720),
    max_attempts: num(v.max_attempts, 5, 3, 10),
    lock_minutes: num(v.lock_minutes, 10, 1, 120),
  };
}

const hex = (b: ArrayBuffer | Uint8Array) => [...new Uint8Array(b)].map((x) => x.toString(16).padStart(2, "0")).join("");

async function hashCode(code: string, salt: string, rideId: number): Promise<string> {
  return hex(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(`${salt}:${rideId}:${code}`)));
}

/** Uniform random 4 digits from the platform's secure generator (rejection sampling, no modulo bias). */
export function randomCode(): string {
  const buf = new Uint32Array(1);
  const limit = Math.floor(0x100000000 / 10000) * 10000;
  do crypto.getRandomValues(buf); while (buf[0] >= limit);
  return String(buf[0] % 10000).padStart(4, "0");
}

export function sameText(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let d = 0;
  for (let i = 0; i < a.length; i++) d |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return d === 0;
}

const note = (db: Client, rideId: number, actor: number | null, event: string) =>
  db.query("insert into app.ride_pickup_events (ride_request_id, actor_id, event) values ($1, $2, $3)", [rideId, actor, event]);

/** A driver was assigned: make (or remake, if a driver backed out and another accepted) the ride's code. Safe to call in the accept transaction. */
export async function issuePickupCode(db: Client, secret: string | undefined, rideId: number): Promise<void> {
  const s = await pickupSettings(db);
  if (!s.enabled) return;
  const code = randomCode();
  const saltBytes = crypto.getRandomValues(new Uint8Array(16));
  const salt = hex(saltBytes);
  await db.query(
    `insert into app.ride_pickup_codes (ride_request_id, code_enc, code_hash, salt, expires_at)
     values ($1, $2, $3, $4, now() + make_interval(mins => $5::int))
     on conflict (ride_request_id) do update set code_enc = excluded.code_enc, code_hash = excluded.code_hash, salt = excluded.salt,
       expires_at = excluded.expires_at, failed_attempts = 0, total_failed = 0, locked_until = null, verified_at = null, verified_by = null,
       overridden_at = null, overridden_by = null, created_at = now()`,
    [rideId, await encryptValue(code, secret), await hashCode(code, salt, rideId), salt, s.expiry_minutes],
  );
  await note(db, rideId, null, "issued");
}

/** What the passenger's app shows: the code until it is verified (or the ride moves on). Null = nothing to show. */
export async function riderPickupView(db: Client, secret: string | undefined, rideId: number, status: string) {
  if (status !== "accepted" && status !== "arrived") return null;
  const row = (await db.query("select * from app.ride_pickup_codes where ride_request_id = $1", [rideId])).rows[0];
  if (!row) return null;
  if (row.verified_at || row.overridden_at) return { verified: true, code: null, expires_at: null };
  try {
    return { verified: false, code: await decryptValue(String(row.code_enc), secret), expires_at: row.expires_at };
  } catch {
    return null;
  }
}

/** For the driver's screen: is a code needed, and has it been accepted? Never the code itself. */
export async function driverPickupFlags(db: Client, rideId: number) {
  const s = await pickupSettings(db);
  const row = (await db.query("select verified_at, overridden_at, locked_until, expires_at from app.ride_pickup_codes where ride_request_id = $1", [rideId])).rows[0];
  if (!s.enabled || !row) return { pickup_required: false, pickup_verified: true, pickup_locked: false };
  const done = !!(row.verified_at || row.overridden_at);
  return {
    pickup_required: !done,
    pickup_verified: done,
    pickup_locked: !!(row.locked_until && new Date(row.locked_until as string).getTime() > Date.now()),
  };
}

type Verify = { ok: true } | { ok: false; code: string; message: string; attempts_left?: number; retry_after_seconds?: number };

/** The driver types the code. One transaction with the row locked, so two requests at once cannot both slip through. */
export async function verifyPickup(db: Client, rideId: number, driverId: number, entered: string): Promise<Verify> {
  const s = await pickupSettings(db);
  await db.query("begin");
  try {
    const ride = (await db.query("select status from app.ride_requests where id = $1 and driver_id = $2 for update", [rideId, driverId])).rows[0];
    if (!ride || ride.status !== "arrived") { await db.query("rollback"); return { ok: false, code: "wrong_state", message: "Tap “I have arrived” first, then enter the code." }; }
    if (!s.enabled) { await db.query("commit"); return { ok: true }; }
    const row = (await db.query("select * from app.ride_pickup_codes where ride_request_id = $1 for update", [rideId])).rows[0];
    if (!row) { await db.query("commit"); return { ok: true }; } // a ride accepted before pickup codes existed
    if (row.verified_at || row.overridden_at) { await db.query("commit"); return { ok: true }; }
    const now = Date.now();
    if (row.locked_until && new Date(row.locked_until as string).getTime() > now) {
      await db.query("rollback");
      return { ok: false, code: "locked", message: "Too many wrong codes. Try again shortly, or ask DROP support to authorise the trip.", retry_after_seconds: Math.ceil((new Date(row.locked_until as string).getTime() - now) / 1000) };
    }
    if (Number(row.total_failed) >= s.max_attempts * 3) {
      await db.query("rollback");
      return { ok: false, code: "locked_out", message: "This code is locked. Ask DROP support to authorise the trip." };
    }
    if (new Date(row.expires_at as string).getTime() < now) {
      await note(db, rideId, driverId, "expired");
      await db.query("commit");
      return { ok: false, code: "expired", message: "This pickup code has expired. Ask DROP support to authorise the trip." };
    }
    const hash = await hashCode(entered, String(row.salt), rideId);
    if (sameText(hash, String(row.code_hash))) {
      await db.query("update app.ride_pickup_codes set verified_at = now(), verified_by = $2, failed_attempts = 0 where ride_request_id = $1", [rideId, driverId]);
      await note(db, rideId, driverId, "verified");
      await db.query("commit");
      return { ok: true };
    }
    const failed = Number(row.failed_attempts) + 1;
    const lock = failed >= s.max_attempts;
    await db.query(
      `update app.ride_pickup_codes set failed_attempts = $2, total_failed = total_failed + 1,
              locked_until = case when $3 then now() + make_interval(mins => $4::int) else locked_until end where ride_request_id = $1`,
      [rideId, lock ? 0 : failed, lock, s.lock_minutes],
    );
    await note(db, rideId, driverId, lock ? "locked" : "wrong_code");
    await db.query("commit");
    if (lock) return { ok: false, code: "locked", message: `Too many wrong codes. Try again in ${s.lock_minutes} minutes.`, retry_after_seconds: s.lock_minutes * 60 };
    return { ok: false, code: "wrong_code", message: "That code is not right. Check it with the passenger.", attempts_left: s.max_attempts - failed };
  } catch (e) {
    await db.query("rollback").catch(() => {});
    throw e;
  }
}

/** SQL condition (with the "pickup codes are on" flag as parameter $n) that lets the start update run only when the code was verified or overridden, or no code applies. */
export const startAllowedSql = (n: number) => `(
  not $${n}::boolean
  or not exists (select 1 from app.ride_pickup_codes c where c.ride_request_id = app.ride_requests.id)
  or exists (select 1 from app.ride_pickup_codes c where c.ride_request_id = app.ride_requests.id and (c.verified_at is not null or c.overridden_at is not null))
)`;

/** Admin authorises the start without the code (passenger has no app, lost the code, driver locked out). Logged. */
export async function overridePickup(db: Client, rideId: number, adminId: number): Promise<boolean> {
  const r = await db.query(
    `update app.ride_pickup_codes set overridden_at = now(), overridden_by = $2
      where ride_request_id = $1 and verified_at is null and overridden_at is null
        and exists (select 1 from app.ride_requests q where q.id = $1 and q.status in ('accepted', 'arrived'))`,
    [rideId, adminId],
  );
  if (!r.rowCount) return false;
  await note(db, rideId, adminId, "override");
  return true;
}
