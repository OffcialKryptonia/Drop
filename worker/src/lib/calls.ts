import type { Client } from "pg";
import type { Bindings } from "../env";
import { decryptValue, encryptValue } from "./crypto";
import { agoraToken, livekitToken } from "./call-tokens";
import { sendPush } from "./push";

export type Provider = "livekit" | "agora";
export const LIVE = ["ringing", "active"] as const;

export type CallSettings = {
  enabled: boolean;
  /** Preferred provider; the other one is used when this one is switched off or not set up. */
  provider: Provider;
  livekit_enabled: boolean;
  agora_enabled: boolean;
  ring_seconds: number;
  max_minutes: number;
  livekit_url: string;
  livekit_api_key: string;
  agora_app_id: string;
};

const num = (x: unknown, d: number, min: number, max: number) => {
  const n = Number(x);
  return Number.isFinite(n) ? Math.min(max, Math.max(min, Math.round(n))) : d;
};

const SECRET_KEY: Record<Provider, string> = { livekit: "calls_livekit_secret_enc", agora: "calls_agora_certificate_enc" };

export async function callSettings(db: Client): Promise<CallSettings> {
  const v = ((await db.query("select value from app.settings where key = 'calls'")).rows[0]?.value ?? {}) as Record<string, unknown>;
  const s = (x: unknown) => (typeof x === "string" ? x.trim() : "");
  return {
    enabled: v.enabled === true, // calling is opt-in: nothing rings until an admin turns it on and adds a provider
    provider: v.provider === "agora" ? "agora" : "livekit",
    livekit_enabled: v.livekit_enabled === true,
    agora_enabled: v.agora_enabled === true,
    ring_seconds: num(v.ring_seconds, 30, 10, 60),
    max_minutes: num(v.max_minutes, 60, 5, 240),
    livekit_url: s(v.livekit_url),
    livekit_api_key: s(v.livekit_api_key),
    agora_app_id: s(v.agora_app_id),
  };
}

export async function secretSaved(db: Client, p: Provider): Promise<boolean> {
  return ((await db.query("select 1 from app.settings where key = $1", [SECRET_KEY[p]])).rowCount ?? 0) > 0;
}

export async function saveSecret(db: Client, env: Bindings, p: Provider, plain: string) {
  await db.query("insert into app.settings (key, value) values ($1, to_jsonb($2::text)) on conflict (key) do update set value = excluded.value", [SECRET_KEY[p], await encryptValue(plain, env.SETTINGS_ENCRYPTION_KEY)]);
}

async function readSecret(db: Client, env: Bindings, p: Provider): Promise<string | null> {
  const enc = (await db.query("select value #>> '{}' as v from app.settings where key = $1", [SECRET_KEY[p]])).rows[0]?.v;
  if (!enc) return null;
  try { return await decryptValue(String(enc), env.SETTINGS_ENCRYPTION_KEY); } catch { return null; }
}

/** Which providers can actually place a call right now (switched on AND fully set up). */
export async function readyProviders(db: Client, s: CallSettings): Promise<Provider[]> {
  const out: Provider[] = [];
  if (s.livekit_enabled && s.livekit_url && s.livekit_api_key && (await secretSaved(db, "livekit"))) out.push("livekit");
  if (s.agora_enabled && s.agora_app_id && (await secretSaved(db, "agora"))) out.push("agora");
  return out;
}

export async function pickProvider(db: Client, s: CallSettings): Promise<Provider | null> {
  if (!s.enabled) return null;
  const ready = await readyProviders(db, s);
  if (!ready.length) return null;
  return ready.includes(s.provider) ? s.provider : ready[0];
}

/** What the app needs to join the room. The token is valid only for this room and this person. */
export async function joinInfo(db: Client, env: Bindings, call: { id: number; provider: Provider; room: string }, userId: number, name: string, ttlSeconds: number) {
  const s = await callSettings(db);
  const secret = await readSecret(db, env, call.provider);
  if (!secret) throw new Error("The calling provider is not set up.");
  if (call.provider === "livekit") {
    const token = await livekitToken({ apiKey: s.livekit_api_key, apiSecret: secret, room: call.room, identity: String(userId), name, ttlSeconds });
    return { provider: "livekit" as const, url: s.livekit_url, token, room: call.room, uid: String(userId) };
  }
  const token = await agoraToken({ appId: s.agora_app_id, appCertificate: secret, channel: call.room, uid: String(userId), ttlSeconds });
  return { provider: "agora" as const, app_id: s.agora_app_id, token, room: call.room, uid: userId };
}

/** The room name is random and unguessable, but access never depends on it: tokens are issued per person. */
export const newRoom = (rideId: number) => `ride${rideId}-${crypto.randomUUID().replace(/-/g, "").slice(0, 16)}`;

export const callView = (c: Record<string, unknown>, me: number) => ({
  id: Number(c.id),
  ride_id: Number(c.ride_request_id),
  status: String(c.status),
  mine: Number(c.caller_id) === me ? "caller" : "callee",
  provider: String(c.provider),
  created_at: c.created_at,
  answered_at: c.answered_at,
  ended_at: c.ended_at,
  duration_seconds: c.duration_seconds === null || c.duration_seconds === undefined ? null : Number(c.duration_seconds),
  end_reason: c.end_reason ?? null,
});

/**
 * Closes calls that can no longer go on: rings nobody answered in time (missed), calls whose trip is no longer
 * open, and calls that ran past the longest allowed. Safe to run at any moment, by the cron or lazily on a request.
 */
export async function sweepCalls(db: Client, env: Bindings, onlyRide?: number): Promise<number> {
  const s = await callSettings(db);
  const missed = (await db.query(
    `update app.ride_calls c set status = 'missed', end_reason = 'no_answer', ended_at = now()
      where c.status = 'ringing' and c.created_at < now() - make_interval(secs => $1::int) ${onlyRide ? "and c.ride_request_id = $2" : ""}
      returning c.id, c.ride_request_id, c.caller_id, c.callee_id`, onlyRide ? [s.ring_seconds, onlyRide] : [s.ring_seconds])).rows;
  for (const m of missed) {
    const who = (await db.query("select coalesce(nullif(trim(concat_ws(' ', first_name, last_name)), ''), 'Someone') as n from app.users where id = $1", [m.caller_id])).rows[0]?.n ?? "Someone";
    await sendPush(db, env, [Number(m.callee_id)], { title: "Missed call", body: `${who} tried to call you.`, data: { type: "call_missed", ride_id: String(m.ride_request_id), call_id: String(m.id) } });
  }

  const ended = (await db.query(
    `update app.ride_calls c
        set status = 'ended', ended_at = now(),
            end_reason = case when r.status in ('accepted','arrived','in_progress') then 'time_limit' else 'ride_closed' end,
            duration_seconds = greatest(0, floor(extract(epoch from (now() - c.answered_at)))::int)
       from app.ride_requests r
      where r.id = c.ride_request_id and c.status = 'active'
        and (r.status not in ('accepted','arrived','in_progress') or r.driver_id is distinct from c.driver_id
             or c.answered_at < now() - make_interval(mins => $1::int)) ${onlyRide ? "and c.ride_request_id = $2" : ""}`, onlyRide ? [s.max_minutes, onlyRide] : [s.max_minutes])).rowCount ?? 0;
  const dropped = (await db.query(
    `update app.ride_calls c set status = 'cancelled', end_reason = 'ride_closed', ended_at = now()
       from app.ride_requests r
      where r.id = c.ride_request_id and c.status = 'ringing'
        and (r.status not in ('accepted','arrived','in_progress') or r.driver_id is distinct from c.driver_id) ${onlyRide ? "and c.ride_request_id = $1" : ""}`, onlyRide ? [onlyRide] : [])
  ).rowCount ?? 0;
  return missed.length + ended + dropped;
}
