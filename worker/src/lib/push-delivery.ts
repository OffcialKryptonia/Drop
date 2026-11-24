import type { Client } from "pg";
import type { Bindings } from "../env";
import { deliverPush } from "./push-core";
import {
  EVENTS, EVENT_BY_KEY, isVar, money, placeholders, renderText, safeDeepLink, sampleValues, usesSensitive,
} from "./push-templates";

/**
 * Template-driven push delivery. The one entry point is notify(): it finds the template for an event key, fills in
 * the variables, logs one delivery row per person, sends through OneSignal and schedules retries for failures that
 * can clear by themselves.
 *
 * It NEVER throws: a notification problem must not break the ride, wallet or admin action that caused it.
 * If the template tables do not exist yet (migration not applied) it sends the built-in text exactly as before.
 */

export type NotifyOpts = {
  key: string;
  userIds: number[];
  vars?: Record<string, unknown>;
  rideId?: number | null;
  /** Extra app data. `type` and ids let the apps refresh the right screen; they never carry authority. */
  data?: Record<string, string>;
  /** undefined: once per person per ride per window. null: never dedupe (chat, calls). A string: that key per person. */
  dedupe?: string | null;
  dedupeSeconds?: number;
  /** A test send: ignores the template's on/off state, uses sample values for anything not given, is never deduped. */
  test?: { adminId: number } | null;
};
export type NotifyResult = { sent: number; failed: number; skipped: number; error?: string };

const RIDE_VARS = ["passenger_name", "driver_name", "ride_id", "pickup_location", "destination", "airport_name", "airport_code", "terminal", "fare"];

async function rideVars(db: Client, rideId: number): Promise<Record<string, string>> {
  try {
    const r = (await db.query(
      `select r.id, r.fare, r.currency, r.pickup_address, r.dropoff_address, r.flight,
              rd.first_name as passenger_name, dr.first_name as driver_name, a.name as airport_name, a.iata_code
         from app.ride_requests r
         join app.users rd on rd.id = r.rider_id
         left join app.users dr on dr.id = r.driver_id
         left join app.airports a on a.id = r.airport_id
        where r.id = $1`, [rideId])).rows[0];
    if (!r) return {};
    return {
      passenger_name: r.passenger_name ?? "", driver_name: r.driver_name ?? "", ride_id: String(r.id),
      pickup_location: r.pickup_address ?? "", destination: r.dropoff_address ?? "",
      airport_name: r.airport_name ?? "", airport_code: r.iata_code ?? "", terminal: r.flight?.terminal ?? "",
      fare: money(r.fare, r.currency),
    };
  } catch (e) { console.error("push ride vars", (e as Error).message); return {}; }
}

export async function linkHosts(db: Client): Promise<string[]> {
  try {
    const v = (await db.query("select value #>> '{}' as v from app.settings where key = 'push_link_hosts'")).rows[0]?.v;
    return String(v ?? "").split(/[,\s]+/).map((h) => h.trim().toLowerCase()).filter(Boolean);
  } catch { return []; }
}

type Content = { id: number | null; title: string; body: string; image: string | null; link: string | null };

export async function notify(db: Client, env: Bindings, o: NotifyOpts): Promise<NotifyResult> {
  const result: NotifyResult = { sent: 0, failed: 0, skipped: 0 };
  try {
    const userIds = [...new Set(o.userIds.filter((n) => Number.isInteger(n) && n > 0))];
    if (!userIds.length) return { ...result, error: "No one to send to." };

    // 1. Which text? The saved template if there is one, else the built-in default for that event.
    let logOk = true;
    let tpl: Record<string, unknown> | null = null;
    try { tpl = (await db.query("select id, status, title, body, image_url, deep_link from app.push_templates where key = $1 and deleted_at is null", [o.key])).rows[0] ?? null; }
    catch { logOk = false; }
    const def = EVENT_BY_KEY.get(o.key);
    let content: Content;
    if (tpl) {
      if (tpl.status !== "active" && !o.test) {
        if (logOk) await logRows(db, o, Number(tpl.id), userIds, "skipped", "Template is switched off.");
        return { ...result, skipped: userIds.length };
      }
      content = { id: Number(tpl.id), title: String(tpl.title), body: String(tpl.body), image: (tpl.image_url as string) ?? null, link: (tpl.deep_link as string) ?? null };
    } else if (def) {
      content = { id: null, title: def.title, body: def.body, image: null, link: null };
    } else return { ...result, error: `No template for ${o.key}.` };

    // 2. Which variables does that text use?
    const used = new Set([...placeholders(content.title).names, ...placeholders(content.body).names, ...placeholders(content.link ?? "").names]);
    let base: Record<string, unknown> = o.test ? sampleValues() : {};
    if (o.rideId && !o.test && RIDE_VARS.some((n) => used.has(n) && !(o.vars && n in o.vars))) base = { ...(await rideVars(db, o.rideId)) };
    base = { ...base, ...(o.vars ?? {}) };
    const needsWallet = used.has("wallet_balance") && !(o.vars && "wallet_balance" in o.vars);

    // 3. Who can receive it, and what exactly does each person get?
    const people = (await db.query("select id, player_id from app.users where id = any($1::bigint[])", [userIds])).rows;
    const hosts = content.link ? await linkHosts(db) : [];
    const sensitive = usesSensitive(content.title, content.body);
    type Item = { userId: number; device: string | null; title: string; body: string; link: string | null; shownTitle: string; shownBody: string };
    const items: Item[] = [];
    for (const p of people) {
      const values = { ...base };
      if (needsWallet) {
        const w = (await db.query("select balance, currency from app.wallets where user_id = $1 order by kind limit 1", [p.id]).catch(() => ({ rows: [] as { balance?: unknown; currency?: unknown }[] }))).rows[0];
        values.wallet_balance = w ? money(w.balance, w.currency) : "";
      }
      const title = renderText(content.title, values), body = renderText(content.body, values);
      let link: string | null = content.link ? renderText(content.link, values, { encode: true }) : null;
      if (link && !safeDeepLink(link, hosts)) link = null; // a link that is no longer allowed is dropped, the notification still goes
      items.push({
        userId: Number(p.id), device: p.player_id ? String(p.player_id) : null, title, body, link,
        shownTitle: sensitive ? renderText(content.title, values, { mask: true }) : title,
        shownBody: sensitive ? renderText(content.body, values, { mask: true }) : body,
      });
    }

    // 4. Log, then send each group of identical messages in one OneSignal request.
    const windowS = o.dedupeSeconds ?? 120;
    const bucket = Math.floor(Date.now() / 1000 / windowS);
    const dedupeBase = o.test ? null : o.dedupe === undefined ? (o.rideId ? `${o.key}:${o.rideId}` : null) : o.dedupe;
    const groups = new Map<string, { key: string; rows: { id: number | null; device: string }[]; item: Item }>();
    for (const it of items) {
      if (!it.device) {
        if (logOk) await insertRow(db, o, content.id, it, "skipped", "No phone is registered for this person.", null, null, 0);
        result.skipped++;
        continue;
      }
      const gk = `${it.title}\u0000${it.body}\u0000${it.link ?? ""}`;
      let g = groups.get(gk);
      if (!g) { g = { key: crypto.randomUUID(), rows: [], item: it }; groups.set(gk, g); }
      let id: number | null = null;
      if (logOk) {
        try {
          id = await insertRow(db, o, content.id, it, "queued", null, g.key, dedupeBase ? `${dedupeBase}:${it.userId}` : null, bucket);
          if (id === null) { result.skipped++; continue; } // the same notification went to this person a moment ago
        } catch (e) { console.error("push log", (e as Error).message); logOk = false; }
      }
      g.rows.push({ id, device: it.device });
    }
    for (const g of groups.values()) {
      if (!g.rows.length) continue;
      const data: Record<string, string> = { ...(o.data ?? {}), template: o.key };
      if (g.item.link) data.deep_link = g.item.link;
      const r = await deliverPush(db, env, g.rows.map((x) => x.device), {
        title: g.item.title, body: g.item.body, data, imageUrl: content.image,
        appUrl: g.item.link && g.item.link.startsWith("drop://") ? g.item.link : null, idempotencyKey: g.key,
      });
      const ids = g.rows.map((x) => x.id).filter((n): n is number => n !== null);
      if (r.sent) result.sent += g.rows.length; else { result.failed += g.rows.length; result.error = r.error; }
      if (logOk && ids.length) {
        await db.query(
          r.sent
            ? "update app.push_deliveries set status = 'sent', attempts = attempts + 1, provider_id = $2, sent_at = now(), reason = null where id = any($1::bigint[])"
            : `update app.push_deliveries set status = 'failed', attempts = attempts + 1, reason = $2, retryable = ($3 and not $4),
                      next_retry_at = case when ($3 and not $4) then now() + interval '1 minute' end where id = any($1::bigint[])`,
          r.sent ? [ids, r.providerId ?? null] : [ids, String(r.error ?? "Failed").slice(0, 300), Boolean(r.retryable), sensitive],
        ).catch((e) => console.error("push log update", (e as Error).message));
      }
    }
    return result;
  } catch (e) {
    console.error("notify", o.key, (e as Error).message);
    return { ...result, error: (e as Error).message };
  }
}

async function insertRow(db: Client, o: NotifyOpts, templateId: number | null, it: { userId: number; title: string; body: string; link: string | null; shownTitle: string; shownBody: string },
  status: string, reason: string | null, idemKey: string | null, dedupeKey: string | null, bucket: number | null): Promise<number | null> {
  const r = await db.query(
    `insert into app.push_deliveries (template_id, template_key, is_test, sent_by, user_id, ride_id, title, body, deep_link, status, reason, idempotency_key, dedupe_key, dedupe_bucket)
     values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14) on conflict do nothing returning id`,
    [templateId, o.key, Boolean(o.test), o.test?.adminId ?? null, it.userId, o.rideId ?? null, it.shownTitle, it.shownBody, it.link, status, reason, idemKey ?? crypto.randomUUID(), dedupeKey, bucket]);
  return r.rows[0] ? Number(r.rows[0].id) : null;
}

async function logRows(db: Client, o: NotifyOpts, templateId: number, userIds: number[], status: string, reason: string) {
  for (const userId of userIds) {
    await insertRow(db, o, templateId, { userId, title: "(not sent)", body: "(not sent)", link: null, shownTitle: "(not sent)", shownBody: "(not sent)" }, status, reason, null, null, null).catch(() => null);
  }
}

/**
 * Every minute: resend notifications OneSignal could not take because of a problem that can clear by itself
 * (network, 429, 5xx). At most 3 tries over about 30 minutes; the same idempotency key is reused so a retry that
 * actually got through the first time is not delivered twice. Rows holding a pickup code or wallet balance are never retried.
 */
export async function retryPushes(db: Client, env: Bindings): Promise<number> {
  let resent = 0;
  try {
    const due = (await db.query(
      `update app.push_deliveries d set next_retry_at = now() + interval '5 minutes'
        where d.id in (select id from app.push_deliveries
                        where status = 'failed' and retryable and not is_test and attempts < 3 and next_retry_at <= now() and created_at > now() - interval '30 minutes'
                        order by next_retry_at limit 100 for update skip locked)
       returning d.id, d.idempotency_key, d.title, d.body, d.deep_link, d.template_id,
                 (select u.player_id from app.users u where u.id = d.user_id) as device,
                 (select t.image_url from app.push_templates t where t.id = d.template_id) as image`)).rows;
    const groups = new Map<string, typeof due>();
    for (const r of due) { const g = groups.get(String(r.idempotency_key)) ?? []; g.push(r); groups.set(String(r.idempotency_key), g); }
    for (const [key, rows] of groups) {
      const withDevice = rows.filter((r) => r.device);
      const noDevice = rows.filter((r) => !r.device).map((r) => Number(r.id));
      if (noDevice.length) await db.query("update app.push_deliveries set retryable = false, next_retry_at = null, reason = 'No phone is registered for this person.' where id = any($1::bigint[])", [noDevice]);
      if (!withDevice.length) continue;
      const first = withDevice[0];
      const link = first.deep_link as string | null;
      const r = await deliverPush(db, env, withDevice.map((x) => String(x.device)), {
        title: String(first.title), body: String(first.body), data: link ? { deep_link: link } : {}, imageUrl: first.image ?? null,
        appUrl: link && link.startsWith("drop://") ? link : null, idempotencyKey: key,
      });
      const ids = withDevice.map((x) => Number(x.id));
      if (r.sent) {
        resent += ids.length;
        await db.query("update app.push_deliveries set status = 'sent', attempts = attempts + 1, provider_id = $2, sent_at = now(), reason = null, retryable = false, next_retry_at = null where id = any($1::bigint[])", [ids, r.providerId ?? null]);
      } else {
        await db.query(
          `update app.push_deliveries set attempts = attempts + 1, reason = $2, retryable = ($3 and attempts + 1 < 3),
                  next_retry_at = case when ($3 and attempts + 1 < 3) then now() + interval '5 minutes' end where id = any($1::bigint[])`,
          [ids, String(r.error ?? "Failed").slice(0, 300), Boolean(r.retryable)]);
      }
    }
  } catch (e) { console.error("push retry", (e as Error).message); }
  return resent;
}

/**
 * Creates the built-in templates that are missing. Existing rows, including edited ones, are never touched.
 * Templates for events that exist today and already sent a push start ON (same text as before). Events connected for
 * the first time in Phase 4, and events nothing fires yet, start OFF so merging changes nothing a rider or driver sees.
 */
export async function ensureSystemTemplates(db: Client): Promise<number> {
  const have = new Set((await db.query("select key from app.push_templates where deleted_at is null")).rows.map((r) => String(r.key)));
  const missing = EVENTS.filter((e) => !have.has(e.key));
  if (!missing.length) return 0;
  const params: unknown[] = [];
  const tuples = missing.map((e) => {
    const vars = [...new Set([...placeholders(e.title).names, ...placeholders(e.body).names])].filter((n) => isVar(n));
    const status = e.wired && !e.fresh ? "active" : "inactive";
    params.push(e.key, e.name, e.category, e.audience, e.title, e.body, vars, status);
    const n = params.length;
    return `($${n - 7},$${n - 6},$${n - 5},$${n - 4},$${n - 3},$${n - 2},$${n - 1}::text[],$${n},true)`;
  });
  const ins = (await db.query(
    `insert into app.push_templates (key, name, category, audience, title, body, variables, status, is_system) values ${tuples.join(",")}
     on conflict do nothing returning id, key, name, category, audience, title, body, status`, params)).rows;
  for (const r of ins) {
    await db.query("insert into app.push_template_versions (template_id, version, snapshot, note) values ($1, 1, $2::jsonb, 'Built-in default') on conflict do nothing",
      [r.id, JSON.stringify({ key: r.key, name: r.name, category: r.category, audience: r.audience, title: r.title, body: r.body, status: r.status })]);
  }
  return ins.length;
}
