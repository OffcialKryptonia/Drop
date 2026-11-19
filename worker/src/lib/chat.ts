import type { Client } from "pg";
import type { Bindings } from "../env";

type Row = Record<string, unknown>;

export type ChatSettings = { enabled: boolean; voice_enabled: boolean; max_voice_seconds: number; retention_days: number };

export async function chatSettings(db: Client): Promise<ChatSettings> {
  const v = ((await db.query("select value from app.settings where key = 'chat'")).rows[0]?.value ?? {}) as Record<string, unknown>;
  const num = (x: unknown, d: number, min: number, max: number) => {
    const n = Number(x);
    return Number.isFinite(n) ? Math.min(max, Math.max(min, Math.round(n))) : d;
  };
  return {
    enabled: v.enabled !== false,
    voice_enabled: v.voice_enabled !== false,
    max_voice_seconds: num(v.max_voice_seconds, 60, 10, 180),
    retention_days: num(v.retention_days, 30, 1, 365),
  };
}

/** The ride's two people, from this person's point of view. Null = this person is not part of the ride, so nothing is shown. */
export async function chatRide(db: Client, rideId: number, userId: number) {
  const r = (await db.query(
    `select r.id, r.status, r.rider_id, r.driver_id,
            rd.first_name as rider_first, rd.last_name as rider_last, dr.first_name as driver_first, dr.last_name as driver_last
       from app.ride_requests r join app.users rd on rd.id = r.rider_id left join app.users dr on dr.id = r.driver_id
      where r.id = $1 and (r.rider_id = $2 or r.driver_id = $2)`, [rideId, userId])).rows[0];
  if (!r) return null;
  const mine = Number(r.rider_id) === userId ? "rider" : "driver";
  const peerId = mine === "rider" ? Number(r.driver_id ?? 0) : Number(r.rider_id);
  const name = (f: unknown, l: unknown) => [f, l].filter(Boolean).join(" ").trim();
  return {
    id: Number(r.id), status: String(r.status), mine, peerId,
    riderId: Number(r.rider_id), driverId: r.driver_id ? Number(r.driver_id) : null,
    peerName: mine === "rider" ? name(r.driver_first, r.driver_last) : name(r.rider_first, r.rider_last),
    // Sending is allowed only while the driver is assigned and the trip is open.
    open: !!r.driver_id && ["accepted", "arrived", "in_progress"].includes(String(r.status)),
  };
}

export const messageView = (m: Row, me: number) => ({
  id: Number(m.id),
  kind: m.kind,
  body: m.kind === "text" ? m.body : null,
  seconds: m.audio_seconds === null ? null : Number(m.audio_seconds),
  waveform: Array.isArray(m.waveform) ? (m.waveform as number[]).map(Number) : null,
  mine: Number(m.sender_id) === me,
  client_id: m.client_id,
  created_at: m.created_at,
  delivered_at: m.delivered_at,
  read_at: m.read_at,
});

// ---- Short-lived audio links (the audio player cannot send our login header) ----

const hex = (b: ArrayBuffer) => [...new Uint8Array(b)].map((x) => x.toString(16).padStart(2, "0")).join("");
async function sign(secret: string, text: string): Promise<string> {
  const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  return hex(await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(text)));
}
const need = (secret: string | undefined) => {
  if (!secret || secret.length < 32) throw new Error("SETTINGS_ENCRYPTION_KEY must be set (32+ characters)");
  return secret;
};

/** A link valid for 10 minutes, for one person and one message. */
export async function audioToken(secret: string | undefined, messageId: number, userId: number): Promise<{ exp: number; sig: string }> {
  const exp = Math.floor(Date.now() / 1000) + 600;
  return { exp, sig: await sign(need(secret), `chat-audio:${messageId}:${userId}:${exp}`) };
}
export async function audioTokenValid(secret: string | undefined, messageId: number, userId: number, exp: number, sig: string): Promise<boolean> {
  if (!Number.isFinite(exp) || exp < Math.floor(Date.now() / 1000)) return false;
  const want = await sign(need(secret), `chat-audio:${messageId}:${userId}:${exp}`);
  if (want.length !== sig.length) return false;
  let d = 0;
  for (let i = 0; i < want.length; i++) d |= want.charCodeAt(i) ^ sig.charCodeAt(i);
  return d === 0;
}

/** Judge audio by its bytes, never by the name or header the app sent. */
export function sniffAudio(b: Uint8Array): { type: string; ext: string } | null {
  const at = (i: number, ...v: number[]) => v.every((x, k) => b[i + k] === x);
  if (b.length > 12 && at(4, 0x66, 0x74, 0x79, 0x70)) return { type: "audio/mp4", ext: "m4a" }; // ....ftyp
  if (at(0, 0x4f, 0x67, 0x67, 0x53)) return { type: "audio/ogg", ext: "ogg" }; // OggS
  if (at(0, 0x1a, 0x45, 0xdf, 0xa3)) return { type: "audio/webm", ext: "webm" }; // EBML
  if (at(0, 0x49, 0x44, 0x33) || (b[0] === 0xff && (b[1] & 0xe0) === 0xe0)) return { type: "audio/mpeg", ext: "mp3" };
  return null;
}

export const MAX_AUDIO_BYTES = 3 * 1024 * 1024;

/** Removes voice files and messages older than the retention period. A small batch each minute. */
export async function purgeOldChat(db: Client, env: Bindings): Promise<number> {
  const days = (await chatSettings(db)).retention_days;
  const old = (await db.query("select id, audio_key from app.ride_messages where created_at < now() - make_interval(days => $1::int) order by id limit 50", [days])).rows;
  for (const m of old) if (m.audio_key && env.DOCS) await env.DOCS.delete(String(m.audio_key)).catch(() => undefined);
  if (old.length) await db.query("delete from app.ride_messages where id = any($1::bigint[])", [old.map((m) => m.id)]);
  return old.length;
}

/** Messages from the other person this user has not opened yet (for the badge on the ride screen). */
export async function chatUnread(db: Client, rideId: number, driverId: number | null, userId: number): Promise<number> {
  if (!driverId) return 0;
  return Number((await db.query("select count(*) from app.ride_messages where ride_request_id = $1 and driver_id = $2 and sender_id <> $3 and read_at is null", [rideId, driverId, userId])).rows[0].count);
}
