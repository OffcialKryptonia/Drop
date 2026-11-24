import { Hono, type Context } from "hono";
import { z } from "zod";
import type { AppEnv } from "../env";
import { withDb } from "../db";
import { requireAuth } from "../auth/middleware";
import { guard, audit } from "../lib/permissions";
import { readBody, validationFailed } from "../lib/legacy";
import { pushLater } from "../lib/push";
import { notify } from "../lib/push-delivery";
import { MAX_AUDIO_BYTES, audioToken, audioTokenValid, chatRide, chatSettings, messageView, sniffAudio } from "../lib/chat";

/**
 * Chat between a passenger and the driver assigned to the same ride. It works the same from both modes:
 * the person is checked against the ride itself (rider or assigned driver), never against an id they send.
 */
export const rideChatRoutes = new Hono<AppEnv>();
type C = Context<AppEnv>;
const mw = [withDb, requireAuth] as const;

const rideIdOf = (c: C) => {
  const id = Number(c.req.param("id"));
  return Number.isInteger(id) && id > 0 ? id : null;
};
const gone = (c: C) => c.json({ status: false, code: "not_found", message: "Chat not found." }, 404);

type Ctx = NonNullable<Awaited<ReturnType<typeof chatRide>>>;

async function load(c: C): Promise<Ctx | null> {
  const id = rideIdOf(c);
  return id ? chatRide(c.get("db"), id, c.get("user").id) : null;
}

/** Messages that belong to the driver now assigned (an earlier driver's messages are never shown to a later one). */
const visible = "ride_request_id = $1 and driver_id = $2";

const view = async (c: C, ride: Ctx, extra: Record<string, unknown> = {}) => {
  const s = await chatSettings(c.get("db"));
  return {
    enabled: s.enabled, voice_enabled: s.voice_enabled, max_voice_seconds: s.max_voice_seconds,
    can_send: s.enabled && ride.open, ride_status: ride.status, peer: { name: ride.peerName || (ride.mine === "rider" ? "Driver" : "Passenger") },
    ...extra,
  };
};

rideChatRoutes.get("/ride/:id/chat", ...mw, async (c) => {
  const ride = await load(c);
  if (!ride) return gone(c);
  const db = c.get("db");
  const me = c.get("user").id;
  const base = await view(c, ride);
  if (!base.enabled || !ride.driverId) return c.json({ status: true, data: { ...base, messages: [], unread: 0, has_more: false } });

  await db.query(
    "insert into app.ride_chat_presence (ride_request_id, user_id, seen_at) values ($1, $2, now()) on conflict (ride_request_id, user_id) do update set seen_at = now()",
    [ride.id, me],
  );
  await db.query(`update app.ride_messages set delivered_at = now() where ${visible} and sender_id <> $3 and delivered_at is null`, [ride.id, ride.driverId, me]);

  const after = Number(c.req.query("after")) || 0;
  const before = Number(c.req.query("before")) || 0;
  const limit = Math.min(50, Math.max(1, Number(c.req.query("limit")) || 30));
  let rows: Record<string, unknown>[];
  let hasMore = false;
  if (after) {
    rows = (await db.query(`select * from app.ride_messages where ${visible} and id > $3 order by id asc limit 100`, [ride.id, ride.driverId, after])).rows;
  } else {
    const params: unknown[] = [ride.id, ride.driverId];
    let cond = "";
    if (before) { params.push(before); cond = "and id < $3"; }
    const got = (await db.query(`select * from app.ride_messages where ${visible} ${cond} order by id desc limit ${limit + 1}`, params)).rows;
    hasMore = got.length > limit;
    rows = got.slice(0, limit).reverse();
  }
  const unread = Number((await db.query(`select count(*) from app.ride_messages where ${visible} and sender_id <> $3 and read_at is null`, [ride.id, ride.driverId, me])).rows[0].count);
  return c.json({ status: true, data: { ...base, messages: rows.map((m) => messageView(m, me)), unread, has_more: hasMore } });
});

/** The person has seen the conversation up to the latest message. */
rideChatRoutes.post("/ride/:id/chat/read", ...mw, async (c) => {
  const ride = await load(c);
  if (!ride) return gone(c);
  if (ride.driverId) {
    await c.get("db").query(
      `update app.ride_messages set read_at = now(), delivered_at = coalesce(delivered_at, now()) where ${visible} and sender_id <> $3 and read_at is null`,
      [ride.id, ride.driverId, c.get("user").id],
    );
  }
  return c.json({ status: true });
});

/** At most 20 messages a minute from one person in one ride. */
async function tooFast(c: C, ride: Ctx) {
  const n = Number((await c.get("db").query("select count(*) from app.ride_messages where ride_request_id = $1 and sender_id = $2 and created_at > now() - interval '1 minute'", [ride.id, c.get("user").id])).rows[0].count);
  return n >= 20;
}

async function announce(c: C, ride: Ctx, kind: "text" | "voice") {
  const db = c.get("db");
  if (!ride.peerId) return;
  const seen = (await db.query("select 1 from app.ride_chat_presence where ride_request_id = $1 and user_id = $2 and seen_at > now() - interval '12 seconds'", [ride.id, ride.peerId])).rowCount;
  if (seen) return; // they are looking at the chat right now
  // No message text in the notification: it can show on a locked screen.
  pushLater(c, notify(db, c.env, {
    key: kind === "voice" ? "ride.voice_message" : "ride.chat_message", userIds: [ride.peerId], rideId: ride.id,
    vars: { sender: ride.mine === "rider" ? "Your passenger" : "Your driver" },
    data: { type: "chat_message", ride_id: String(ride.id) }, dedupe: null,
  }));
}

const textSchema = z.object({
  client_id: z.string().trim().min(8).max(64),
  body: z.string().trim().min(1, "Type a message.").max(1000, "Messages can be up to 1000 characters."),
});

rideChatRoutes.post("/ride/:id/chat/messages", ...mw, async (c) => {
  const ride = await load(c);
  if (!ride) return gone(c);
  const p = textSchema.safeParse(await readBody(c));
  if (!p.success) return validationFailed(c, { message: [p.error.issues[0].message] });
  const s = await chatSettings(c.get("db"));
  if (!s.enabled) return c.json({ status: false, code: "chat_off", message: "Chat is switched off right now." }, 403);
  if (!ride.open || !ride.driverId) return c.json({ status: false, code: "chat_closed", message: "This chat is closed. Messages can be sent only while the trip is open." }, 409);
  if (await tooFast(c, ride)) return c.json({ status: false, code: "slow_down", message: "You are sending messages too quickly. Wait a moment." }, 429);
  const db = c.get("db");
  const row = (await db.query(
    `insert into app.ride_messages (ride_request_id, driver_id, rider_id, sender_id, kind, body, client_id) values ($1, $2, $3, $4, 'text', $5, $6)
     on conflict (ride_request_id, sender_id, client_id) do nothing returning *`,
    [ride.id, ride.driverId, ride.riderId, c.get("user").id, p.data.body, p.data.client_id])).rows[0];
  if (!row) { // a retry of a message that already went through
    const same = (await db.query("select * from app.ride_messages where ride_request_id = $1 and sender_id = $2 and client_id = $3", [ride.id, c.get("user").id, p.data.client_id])).rows[0];
    return c.json({ status: true, data: messageView(same, c.get("user").id) });
  }
  await announce(c, ride, "text");
  return c.json({ status: true, data: messageView(row, c.get("user").id) }, 201);
});

/** A voice message: the audio goes to the private bucket; only its key and details are saved in the database. */
rideChatRoutes.post("/ride/:id/chat/voice", ...mw, async (c) => {
  const ride = await load(c);
  if (!ride) return gone(c);
  const db = c.get("db");
  const me = c.get("user").id;
  const s = await chatSettings(db);
  if (!s.enabled || !s.voice_enabled) return c.json({ status: false, code: "voice_off", message: "Voice messages are switched off right now." }, 403);
  if (!ride.open || !ride.driverId) return c.json({ status: false, code: "chat_closed", message: "This chat is closed. Messages can be sent only while the trip is open." }, 409);
  if (!c.env.DOCS) return c.json({ status: false, code: "storage_off", message: "Voice messages are not set up yet." }, 503);
  if (await tooFast(c, ride)) return c.json({ status: false, code: "slow_down", message: "You are sending messages too quickly. Wait a moment." }, 429);

  const form = await c.req.parseBody().catch(() => null);
  const clientId = String(form?.client_id ?? "").trim();
  const seconds = Math.round(Number(form?.seconds));
  const file = form?.file;
  if (clientId.length < 8 || clientId.length > 64 || !(file instanceof File)) return validationFailed(c, { voice: ["Record a voice message first."] });
  if (!Number.isFinite(seconds) || seconds < 1) return validationFailed(c, { voice: ["That recording is too short."] });
  if (seconds > s.max_voice_seconds) return validationFailed(c, { voice: [`Voice messages can be up to ${s.max_voice_seconds} seconds.`] });
  if (file.size > MAX_AUDIO_BYTES) return validationFailed(c, { voice: ["That recording is too large."] });

  const dup = (await db.query("select * from app.ride_messages where ride_request_id = $1 and sender_id = $2 and client_id = $3", [ride.id, me, clientId])).rows[0];
  if (dup) return c.json({ status: true, data: messageView(dup, me) });

  const bytes = new Uint8Array(await file.arrayBuffer());
  const kind = sniffAudio(bytes);
  if (!kind) return validationFailed(c, { voice: ["That is not a supported audio recording."] });
  const wave = String(form?.waveform ?? "").split(",").map((x) => Math.round(Number(x))).filter((x) => Number.isFinite(x)).slice(0, 48).map((x) => Math.min(100, Math.max(0, x)));

  const key = `chat/${ride.id}/${crypto.randomUUID()}.${kind.ext}`;
  await c.env.DOCS.put(key, bytes, { httpMetadata: { contentType: kind.type } });
  try {
    const row = (await db.query(
      `insert into app.ride_messages (ride_request_id, driver_id, rider_id, sender_id, kind, audio_key, audio_seconds, audio_bytes, waveform, client_id)
       values ($1, $2, $3, $4, 'voice', $5, $6, $7, $8, $9) returning *`,
      [ride.id, ride.driverId, ride.riderId, me, key, seconds, bytes.length, wave.length ? wave : null, clientId])).rows[0];
    await announce(c, ride, "voice");
    return c.json({ status: true, data: messageView(row, me) }, 201);
  } catch (e) {
    await c.env.DOCS.delete(key).catch(() => undefined);
    throw e;
  }
});

/** A link for one voice message, good for 10 minutes and only for the person who asked. */
rideChatRoutes.get("/ride/:id/chat/messages/:mid/audio-url", ...mw, async (c) => {
  const ride = await load(c);
  const mid = Number(c.req.param("mid"));
  if (!ride || !ride.driverId || !Number.isInteger(mid) || mid <= 0) return gone(c);
  const m = (await c.get("db").query("select id from app.ride_messages where id = $1 and ride_request_id = $2 and driver_id = $3 and kind = 'voice'", [mid, ride.id, ride.driverId])).rows[0];
  if (!m) return gone(c);
  const me = c.get("user").id;
  const t = await audioToken(c.env.SETTINGS_ENCRYPTION_KEY, mid, me);
  return c.json({ status: true, data: { url: `${new URL(c.req.url).origin}/api/chat/audio/${mid}?u=${me}&exp=${t.exp}&sig=${t.sig}`, expires_at: t.exp } });
});

/** The audio itself. No login header (the player cannot send one): the signed, short-lived link is the proof, and the person is checked again. */
rideChatRoutes.get("/chat/audio/:mid", withDb, async (c) => {
  const mid = Number(c.req.param("mid"));
  const u = Number(c.req.query("u"));
  const ok = Number.isInteger(mid) && Number.isInteger(u) && (await audioTokenValid(c.env.SETTINGS_ENCRYPTION_KEY, mid, u, Number(c.req.query("exp")), String(c.req.query("sig") ?? "")));
  if (!ok || !c.env.DOCS) return c.json({ status: false, message: "Link expired." }, 403);
  const m = (await c.get("db").query(
    `select m.audio_key from app.ride_messages m join app.ride_requests r on r.id = m.ride_request_id
      where m.id = $1 and m.kind = 'voice' and (r.rider_id = $2 or r.driver_id = $2) and m.driver_id = coalesce(r.driver_id, m.driver_id)`, [mid, u])).rows[0];
  if (!m?.audio_key) return c.json({ status: false, message: "Not found." }, 404);
  const obj = await c.env.DOCS.get(String(m.audio_key), { range: c.req.raw.headers });
  if (!obj) return c.json({ status: false, message: "Not found." }, 404);
  const h = new Headers({ "Content-Type": obj.httpMetadata?.contentType ?? "audio/mp4", "Accept-Ranges": "bytes", "Cache-Control": "private, no-store" });
  const r = obj.range as { offset?: number; length?: number } | undefined;
  if (r && r.offset !== undefined && r.length !== undefined && (r.offset > 0 || r.length < obj.size)) {
    h.set("Content-Range", `bytes ${r.offset}-${r.offset + r.length - 1}/${obj.size}`);
    h.set("Content-Length", String(r.length));
    return new Response(obj.body, { status: 206, headers: h });
  }
  h.set("Content-Length", String(obj.size));
  return new Response(obj.body, { status: 200, headers: h });
});

// ---- Admin: switches only. Admins do not read private conversations. ----

rideChatRoutes.get("/admin/chat-settings", ...guard("ride_chat list"), async (c) => c.json({ data: await chatSettings(c.get("db")) }));
rideChatRoutes.put("/admin/chat-settings", ...guard("ride_chat edit"), async (c) => {
  const p = z.object({
    enabled: z.boolean(),
    voice_enabled: z.boolean(),
    max_voice_seconds: z.coerce.number().int().min(10, "Use 10 to 180 seconds.").max(180, "Use 10 to 180 seconds."),
    retention_days: z.coerce.number().int().min(1, "Use 1 to 365 days.").max(365, "Use 1 to 365 days."),
  }).safeParse(await readBody(c));
  if (!p.success) return validationFailed(c, { chat: [p.error.issues[0].message] });
  await c.get("db").query("insert into app.settings (key, value) values ('chat', $1::jsonb) on conflict (key) do update set value = excluded.value", [JSON.stringify(p.data)]);
  await audit(c, "chat_settings.update", "chat", p.data);
  return c.json({ status: true, data: p.data });
});
