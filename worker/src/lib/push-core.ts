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

export type TransportResult = { sent: number; error?: string; retryable?: boolean; providerId?: string };

/**
 * One OneSignal request to a set of device (subscription) ids. Never throws.
 * Field names follow OneSignal's "Create notification" reference:
 *  - app_url opens an in-app/custom-scheme link on tap (url is for https links in a browser)
 *  - big_picture (Android) and ios_attachments (iOS) show an image
 *  - idempotency_key (a UUID) makes OneSignal process a repeated request only once
 * `retryable` is true only for failures that can clear by themselves: no network, 429, 5xx.
 */
export async function deliverPush(
  db: Client, env: Bindings, deviceIds: string[],
  msg: PushMessage & { appUrl?: string | null; imageUrl?: string | null; idempotencyKey?: string },
): Promise<TransportResult> {
  try {
    if (!deviceIds.length) return { sent: 0, error: "No phone is registered for that person." };
    const { appId, restKey } = await pushConfig(db, env);
    if (!appId || !restKey) return { sent: 0, error: "Push is not set up yet." };
    const payload: Record<string, unknown> = {
      app_id: appId, target_channel: "push", include_subscription_ids: deviceIds,
      headings: { en: msg.title }, contents: { en: msg.body }, data: msg.data ?? {},
    };
    if (msg.appUrl) payload.app_url = msg.appUrl;
    if (msg.imageUrl) { payload.big_picture = msg.imageUrl; payload.ios_attachments = { image: msg.imageUrl }; }
    if (msg.idempotencyKey) payload.idempotency_key = msg.idempotencyKey;
    const res = await fetch("https://api.onesignal.com/notifications?c=push", {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Key ${restKey}` },
      body: JSON.stringify(payload),
    });
    const text = await res.text();
    let json: { id?: string; errors?: unknown } = {};
    try { json = JSON.parse(text); } catch { /* not json */ }
    // OneSignal can answer 200 with an error list and no notification id: that is a failure, not a send.
    if (!res.ok || !json.id) {
      const why = json.errors ? JSON.stringify(json.errors) : text;
      console.error("push failed", res.status, why.slice(0, 300));
      return { sent: 0, error: `OneSignal said: ${why.slice(0, 200)}`, retryable: res.status === 429 || res.status >= 500 };
    }
    return { sent: deviceIds.length, providerId: json.id };
  } catch (e) {
    console.error("push error", (e as Error).message);
    return { sent: 0, error: (e as Error).message, retryable: true };
  }
}
