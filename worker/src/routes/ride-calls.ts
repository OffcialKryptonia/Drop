import { Hono, type Context } from "hono";
import { z } from "zod";
import type { AppEnv } from "../env";
import { withDb } from "../db";
import { requireAuth } from "../auth/middleware";
import { guard, audit } from "../lib/permissions";
import { readBody, validationFailed } from "../lib/legacy";
import { pushLater } from "../lib/push";
import { notify } from "../lib/push-delivery";
import { chatRide } from "../lib/chat";
import { callSettings, callView, joinInfo, newRoom, pickProvider, readyProviders, saveSecret, secretSaved, sweepCalls } from "../lib/calls";

/**
 * In-app voice calls between a passenger and the driver assigned to the same ride. Every request is checked
 * against the ride itself (rider or assigned driver); the person never sends who they are calling.
 * This server only handles who may call whom, ringing and history. The audio goes through LiveKit or Agora.
 */
export const rideCallRoutes = new Hono<AppEnv>();
type C = Context<AppEnv>;
const mw = [withDb, requireAuth] as const;
const TOKEN_SECONDS = 15 * 60;

const fail = (c: C, status: 400 | 403 | 404 | 409 | 429 | 503, code: string, message: string) => c.json({ status: false, code, message }, status);
const idOf = (c: C, name = "id") => { const n = Number(c.req.param(name)); return Number.isInteger(n) && n > 0 ? n : null; };

/** The call, only if this person is its caller or callee. */
async function myCall(c: C) {
  const id = idOf(c, "cid");
  if (!id) return null;
  const me = c.get("user").id;
  const row = (await c.get("db").query("select * from app.ride_calls where id = $1 and (caller_id = $2 or callee_id = $2)", [id, me])).rows[0];
  if (!row) return null;
  await sweepCalls(c.get("db"), c.env, Number(row.ride_request_id));
  return (await c.get("db").query("select * from app.ride_calls where id = $1", [id])).rows[0] ?? null;
}

async function nameOf(c: C, id: number): Promise<string> {
  return (await c.get("db").query("select coalesce(nullif(trim(concat_ws(' ', first_name, last_name)), ''), 'Someone') as n from app.users where id = $1", [id])).rows[0]?.n ?? "Someone";
}

// ---- What the ride screen needs to show or hide the call button ----
rideCallRoutes.get("/ride/:id/call/status", ...mw, async (c) => {
  const rideId = idOf(c);
  const me = c.get("user").id;
  const ride = rideId ? await chatRide(c.get("db"), rideId, me) : null;
  if (!ride) return fail(c, 404, "not_found", "Ride not found.");
  await sweepCalls(c.get("db"), c.env, ride.id);
  const s = await callSettings(c.get("db"));
  const provider = await pickProvider(c.get("db"), s);
  const cur = (await c.get("db").query("select * from app.ride_calls where ride_request_id = $1 order by id desc limit 1", [ride.id])).rows[0];
  return c.json({ status: true, data: {
    enabled: !!provider, can_call: !!provider && ride.open, peer: { name: ride.peerName || (ride.mine === "rider" ? "Driver" : "Passenger") },
    ring_seconds: s.ring_seconds, call: cur ? callView(cur, me) : null,
  } });
});

// ---- Start a call to the other person on this ride ----
rideCallRoutes.post("/ride/:id/call", ...mw, async (c) => {
  const db = c.get("db");
  const rideId = idOf(c);
  const me = c.get("user").id;
  const ride = rideId ? await chatRide(db, rideId, me) : null;
  if (!ride) return fail(c, 404, "not_found", "Ride not found.");
  if (!ride.open || !ride.driverId) return fail(c, 409, "ride_not_open", "Calls are available while a driver is on the way or the trip is under way.");
  const s = await callSettings(db);
  const provider = await pickProvider(db, s);
  if (!provider) return fail(c, 503, "calls_off", "In-app calling is not available right now.");
  await sweepCalls(db, c.env, ride.id);

  const recent = Number((await db.query("select count(*) from app.ride_calls where ride_request_id = $1 and caller_id = $2 and created_at > now() - interval '10 minutes'", [ride.id, me])).rows[0].count);
  if (recent >= 8) return fail(c, 429, "too_many_calls", "Too many call attempts. Please wait a few minutes.");

  let call;
  try {
    call = (await db.query(
      `insert into app.ride_calls (ride_request_id, driver_id, rider_id, caller_id, callee_id, provider, room)
       values ($1,$2,$3,$4,$5,$6,$7) returning *`,
      [ride.id, ride.driverId, ride.riderId, me, ride.peerId, provider, newRoom(ride.id)])).rows[0];
  } catch (e) {
    if ((e as { code?: string }).code === "23505") {
      const live = (await db.query("select * from app.ride_calls where ride_request_id = $1 and status in ('ringing','active') limit 1", [ride.id])).rows[0];
      return c.json({ status: false, code: "call_in_progress", message: "There is already a call on this trip.", data: live ? callView(live, me) : null }, 409);
    }
    throw e;
  }
  const myName = await nameOf(c, me);
  pushLater(c, notify(db, c.env, { key: "ride.call_incoming", userIds: [ride.peerId], rideId: Number(ride.id), vars: { caller_name: myName }, data: { type: "call_incoming", ride_id: String(ride.id), call_id: String(call.id) }, dedupe: `ride.call_incoming:call${call.id}` }));
  const join = await joinInfo(db, c.env, { id: Number(call.id), provider, room: call.room }, me, myName, TOKEN_SECONDS);
  return c.json({ status: true, data: { call: callView(call, me), join, peer: { name: ride.peerName } } });
});

// ---- Does anyone ring me right now? (polled by the app while a trip is open) ----
rideCallRoutes.get("/calls/incoming", ...mw, async (c) => {
  const db = c.get("db");
  const me = c.get("user").id;
  const rides = (await db.query("select distinct ride_request_id from app.ride_calls where callee_id = $1 and status = 'ringing'", [me])).rows;
  for (const r of rides) await sweepCalls(db, c.env, Number(r.ride_request_id));
  const row = (await db.query(
    `select c.*, coalesce(nullif(trim(concat_ws(' ', u.first_name, u.last_name)), ''), 'Someone') as caller_name
       from app.ride_calls c join app.users u on u.id = c.caller_id
      where c.callee_id = $1 and c.status = 'ringing' order by c.id desc limit 1`, [me])).rows[0];
  return c.json({ status: true, data: row ? { ...callView(row, me), caller_name: row.caller_name } : null });
});

// ---- Poll one call (both sides) ----
rideCallRoutes.get("/call/:cid", ...mw, async (c) => {
  const call = await myCall(c);
  if (!call) return fail(c, 404, "not_found", "Call not found.");
  return c.json({ status: true, data: callView(call, c.get("user").id) });
});

// ---- The person called answers ----
rideCallRoutes.post("/call/:cid/accept", ...mw, async (c) => {
  const db = c.get("db");
  const me = c.get("user").id;
  const call = await myCall(c);
  if (!call || Number(call.callee_id) !== me) return fail(c, 404, "not_found", "Call not found.");
  if (call.status !== "ringing") return fail(c, 409, "not_ringing", call.status === "active" ? "This call was already answered." : "This call has ended.");
  const upd = (await db.query("update app.ride_calls set status = 'active', answered_at = now() where id = $1 and status = 'ringing' returning *", [call.id])).rows[0];
  if (!upd) return fail(c, 409, "not_ringing", "This call has ended.");
  const join = await joinInfo(db, c.env, { id: Number(upd.id), provider: upd.provider, room: upd.room }, me, await nameOf(c, me), TOKEN_SECONDS);
  return c.json({ status: true, data: { call: callView(upd, me), join } });
});

// ---- Fresh join token (reconnect). Only the caller (while ringing/active) or the callee (once answered). ----
rideCallRoutes.post("/call/:cid/token", ...mw, async (c) => {
  const me = c.get("user").id;
  const call = await myCall(c);
  if (!call) return fail(c, 404, "not_found", "Call not found.");
  const mayJoin = call.status === "active" || (call.status === "ringing" && Number(call.caller_id) === me);
  if (!mayJoin) return fail(c, 409, "not_live", "This call has ended.");
  const join = await joinInfo(c.get("db"), c.env, { id: Number(call.id), provider: call.provider, room: call.room }, me, await nameOf(c, me), TOKEN_SECONDS);
  return c.json({ status: true, data: { join } });
});

// ---- Decline (callee), cancel (caller while ringing), end (either, while active) ----
async function finish(c: C, who: "decline" | "cancel" | "end") {
  const db = c.get("db");
  const me = c.get("user").id;
  const call = await myCall(c);
  if (!call) return fail(c, 404, "not_found", "Call not found.");
  if (who === "decline" && Number(call.callee_id) !== me) return fail(c, 403, "not_allowed", "Only the person being called can decline.");
  if (who === "cancel" && Number(call.caller_id) !== me) return fail(c, 403, "not_allowed", "Only the caller can cancel.");
  // Ending an already finished call is not an error: both people may press End at the same moment.
  if (!["ringing", "active"].includes(String(call.status))) return c.json({ status: true, data: callView(call, me) });

  const ringing = call.status === "ringing";
  const next = ringing ? (Number(call.callee_id) === me ? "declined" : "cancelled") : "ended";
  const reason = ringing ? (next === "declined" ? "declined" : "caller_cancelled") : "hung_up";
  const upd = (await db.query(
    `update app.ride_calls set status = $2, end_reason = $3, ended_at = now(),
            duration_seconds = case when answered_at is null then null else greatest(0, floor(extract(epoch from (now() - answered_at)))::int) end
      where id = $1 and status in ('ringing','active') returning *`, [call.id, next, reason])).rows[0];
  const row = upd ?? (await db.query("select * from app.ride_calls where id = $1", [call.id])).rows[0];
  if (upd && next === "cancelled") {
    const name = await nameOf(c, me);
    pushLater(c, notify(db, c.env, { key: "ride.call_missed", userIds: [Number(call.callee_id)], rideId: Number(call.ride_request_id), vars: { caller_name: name }, data: { type: "call_missed", ride_id: String(call.ride_request_id), call_id: String(call.id) }, dedupe: `ride.call_missed:call${call.id}` }));
  }
  return c.json({ status: true, data: callView(row, me) });
}
rideCallRoutes.post("/call/:cid/decline", ...mw, (c) => finish(c, "decline"));
rideCallRoutes.post("/call/:cid/cancel", ...mw, (c) => finish(c, "cancel"));
rideCallRoutes.post("/call/:cid/end", ...mw, (c) => finish(c, "end"));

// ---- The app could not connect to the provider ----
rideCallRoutes.post("/call/:cid/failed", ...mw, async (c) => {
  const call = await myCall(c);
  if (!call) return fail(c, 404, "not_found", "Call not found.");
  await c.get("db").query("update app.ride_calls set status = 'failed', end_reason = 'connect_failed', ended_at = now() where id = $1 and status in ('ringing','active')", [call.id]);
  return c.json({ status: true });
});

// ---- Call history for one ride (both people) ----
rideCallRoutes.get("/ride/:id/calls", ...mw, async (c) => {
  const rideId = idOf(c);
  const me = c.get("user").id;
  const ride = rideId ? await chatRide(c.get("db"), rideId, me) : null;
  if (!ride) return fail(c, 404, "not_found", "Ride not found.");
  const rows = (await c.get("db").query("select * from app.ride_calls where ride_request_id = $1 and driver_id = $2 order by id desc limit 30", [ride.id, ride.driverId ?? 0])).rows;
  return c.json({ status: true, data: rows.map((r) => callView(r, me)) });
});

// ================================================================ Admin
rideCallRoutes.get("/admin/call-settings", ...guard("ride_call list"), async (c) => {
  const db = c.get("db");
  const s = await callSettings(db);
  // Secrets are never sent back: only whether one is saved.
  return c.json({ data: { ...s, livekit_secret_saved: await secretSaved(db, "livekit"), agora_certificate_saved: await secretSaved(db, "agora"), ready: await readyProviders(db, s) } });
});

rideCallRoutes.put("/admin/call-settings", ...guard("ride_call edit"), async (c) => {
  const p = z.object({
    enabled: z.boolean(),
    provider: z.enum(["livekit", "agora"]),
    livekit_enabled: z.boolean(),
    agora_enabled: z.boolean(),
    ring_seconds: z.coerce.number().int().min(10, "Ring time: 10 to 60 seconds.").max(60, "Ring time: 10 to 60 seconds."),
    max_minutes: z.coerce.number().int().min(5, "Longest call: 5 to 240 minutes.").max(240, "Longest call: 5 to 240 minutes."),
    livekit_url: z.string().trim().max(300).refine((v) => v === "" || /^wss?:\/\//i.test(v), "The LiveKit address must start with wss://"),
    livekit_api_key: z.string().trim().max(200),
    agora_app_id: z.string().trim().max(200),
    // Optional: left out or blank means "keep the one already saved".
    livekit_api_secret: z.string().trim().max(400).optional(),
    agora_app_certificate: z.string().trim().max(400).optional(),
  }).safeParse(await readBody(c));
  if (!p.success) return validationFailed(c, { calls: [p.error.issues[0].message] });
  const db = c.get("db");
  const { livekit_api_secret, agora_app_certificate, ...pub } = p.data;
  if (livekit_api_secret) await saveSecret(db, c.env, "livekit", livekit_api_secret);
  if (agora_app_certificate) await saveSecret(db, c.env, "agora", agora_app_certificate);
  await db.query("insert into app.settings (key, value) values ('calls', $1::jsonb) on conflict (key) do update set value = excluded.value", [JSON.stringify(pub)]);
  await audit(c, "call_settings.update", "calls", { ...pub, livekit_secret_changed: !!livekit_api_secret, agora_certificate_changed: !!agora_app_certificate });
  const s = await callSettings(db);
  return c.json({ status: true, data: { ...s, livekit_secret_saved: await secretSaved(db, "livekit"), agora_certificate_saved: await secretSaved(db, "agora"), ready: await readyProviders(db, s) } });
});

/** History for admins: who called whom, when, how long, how it ended. There is no audio and no recording. */
rideCallRoutes.get("/admin/calls", ...guard("ride_call list"), async (c) => {
  const lim = Math.min(200, Math.max(1, Number(c.req.query("limit")) || 50));
  const rows = (await c.get("db").query(
    `select c.id, c.ride_request_id, c.status, c.provider, c.end_reason, c.created_at, c.answered_at, c.ended_at, c.duration_seconds,
            trim(concat_ws(' ', a.first_name, a.last_name)) as caller, trim(concat_ws(' ', b.first_name, b.last_name)) as callee
       from app.ride_calls c join app.users a on a.id = c.caller_id join app.users b on b.id = c.callee_id
      order by c.id desc limit $1`, [lim])).rows;
  return c.json({ data: rows });
});
