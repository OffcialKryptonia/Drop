import type { Client } from "pg";
import type { Bindings } from "../env";
import { decryptValue } from "./crypto";

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
