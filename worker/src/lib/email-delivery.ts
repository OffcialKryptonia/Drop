import type { Client } from "pg";
import type { Bindings } from "../env";
import { deliverEmail } from "./email";
import {
  DEFAULT_BRAND, EMAIL_EVENTS, EMAIL_EVENT_BY_KEY, isVar, normaliseBrand, placeholders, renderEmail, sampleValues, usesSensitive,
  type Brand, type RenderedEmail,
} from "./email-templates";
import { money } from "./push-templates";

/**
 * Template-driven email delivery. The one entry point is notifyEmail(): it finds the template for an event key, fills in
 * the variables, logs one delivery row per recipient, sends through Resend and schedules retries for failures that can
 * clear by themselves.
 *
 * It NEVER throws: an email problem must not break the ride, payment or admin action that caused it.
 * Safety rules that apply even before an admin touches anything:
 *  - Only the password-reset email falls back to its built-in text when no template row exists yet (it is what
 *    people receive today). Every newly connected email stays silent until an admin switches its template on.
 *  - A template holding unsafe HTML is never sent.
 */

export type NotifyEmailOpts = {
  key: string;
  /** Accounts to email (their address and first name come from the account). */
  userIds?: number[];
  /** A specific address, used only for an Admin test send. */
  to?: string;
  vars?: Record<string, unknown>;
  rideId?: number | null;
  /** undefined: once per person per ride per window. null: never dedupe. A string: that key per person. */
  dedupe?: string | null;
  dedupeSeconds?: number;
  /** A test send: ignores the template's on/off state, uses sample values for anything not given, is never deduped. */
  test?: { adminId: number } | null;
};
export type NotifyEmailResult = { sent: number; failed: number; skipped: number; error?: string };

const EMAIL_RE = /^[^\s@<>"']+@[^\s@<>"']+\.[^\s@<>"']{2,}$/;
const RETRY_DELAYS = ["5 minutes", "15 minutes"]; // after attempt 1 and attempt 2; there is no attempt 4
const MAX_ATTEMPTS = 3;

export async function loadBrand(db: Client): Promise<Brand> {
  try {
    const v = (await db.query("select value from app.settings where key = 'email_brand'")).rows[0]?.value;
    return v ? normaliseBrand(v) : { ...DEFAULT_BRAND };
  } catch { return { ...DEFAULT_BRAND }; }
}

const lagos = (d: unknown) => {
  try { return new Date(d as string).toLocaleString("en-GB", { timeZone: "Africa/Lagos", day: "numeric", month: "short", year: "numeric", hour: "2-digit", minute: "2-digit" }); }
  catch { return ""; }
};

const RIDE_VARS = ["passenger_name", "driver_name", "ride_id", "pickup_location", "destination", "airport_name", "airport_code", "terminal", "fare", "ride_date", "flight_number"];

async function rideVars(db: Client, rideId: number): Promise<Record<string, string>> {
  try {
    const r = (await db.query(
      `select r.id, r.fare, r.currency, r.pickup_address, r.dropoff_address, r.flight, r.created_at,
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
      airport_name: r.airport_name ?? "", airport_code: r.iata_code ?? "", terminal: r.flight?.terminal ?? "", flight_number: r.flight?.number ?? r.flight?.flight_number ?? "",
      fare: money(r.fare, r.currency), ride_date: lagos(r.created_at),
    };
  } catch (e) { console.error("email ride vars", (e as Error).message); return {}; }
}

type Source = { id: number | null; subject: string; preheader: string | null; html_body: string; text_body: string };

const builtIn = (key: string): Source | null => {
  const d = EMAIL_EVENT_BY_KEY.get(key);
  return d ? { id: null, subject: d.subject, preheader: d.preheader, html_body: d.html, text_body: d.text } : null;
};

export async function notifyEmail(db: Client, env: Bindings, o: NotifyEmailOpts): Promise<NotifyEmailResult> {
  const result: NotifyEmailResult = { sent: 0, failed: 0, skipped: 0 };
  try {
    const def = EMAIL_EVENT_BY_KEY.get(o.key);
    const userIds = [...new Set((o.userIds ?? []).filter((n) => Number.isInteger(n) && n > 0))];
    if (!userIds.length && !o.to) return { ...result, error: "No one to send to." };
    if (o.to && !EMAIL_RE.test(o.to)) return { ...result, error: "That is not a valid email address." };

    // 1. Which text? The saved template if there is one; the built-in text only for a template marked critical.
    let logOk = true;
    let tpl: (Source & { status: string }) | null = null;
    try {
      const r = (await db.query("select id, status, subject, preheader, html_body, text_body from app.email_templates where key = $1 and deleted_at is null", [o.key])).rows[0];
      if (r) tpl = { id: Number(r.id), status: String(r.status), subject: String(r.subject), preheader: r.preheader ?? null, html_body: String(r.html_body), text_body: String(r.text_body) };
    } catch { logOk = false; }
    let source: Source;
    if (tpl) {
      if (tpl.status !== "active" && !o.test && !def?.locked) {
        if (logOk) for (const id of userIds) await insertRow(db, o, tpl.id, { userId: id, to: "", subject: "(not sent)" }, "skipped", "Template is switched off.", null, null, null).catch(() => null);
        return { ...result, skipped: Math.max(userIds.length, 1) };
      }
      source = tpl;
    } else if (def && (def.locked || o.test)) {
      source = builtIn(o.key)!;
    } else if (def) {
      return { ...result, skipped: Math.max(userIds.length, 1), error: "Template is not switched on yet." };
    } else return { ...result, error: `No template for ${o.key}.` };

    // 2. Variables.
    const used = new Set([...placeholders(source.subject).names, ...placeholders(source.preheader ?? "").names, ...placeholders(source.html_body).names, ...placeholders(source.text_body).names]);
    let base: Record<string, unknown> = o.test ? sampleValues() : {};
    if (o.rideId && !o.test && RIDE_VARS.some((n) => used.has(n) && !(o.vars && n in o.vars))) base = { ...(await rideVars(db, o.rideId)) };
    if (!o.test && used.has("event_time") && !(o.vars && "event_time" in o.vars)) base.event_time = lagos(new Date().toISOString());
    base = { ...base, ...(o.vars ?? {}) };
    const needsWallet = used.has("wallet_balance") && !(o.vars && "wallet_balance" in o.vars);
    const brand = await loadBrand(db);

    // 3. Who gets it?
    type Person = { userId: number | null; to: string; first: string };
    const people: Person[] = [];
    if (userIds.length) {
      const rows = (await db.query("select id, email, first_name from app.users where id = any($1::bigint[]) and deleted_at is null", [userIds])).rows;
      for (const id of userIds) {
        const u = rows.find((r) => Number(r.id) === id);
        people.push({ userId: id, to: u?.email ? String(u.email).trim() : "", first: String(u?.first_name ?? "").trim() });
      }
    }
    if (o.to) people.push({ userId: null, to: o.to.trim(), first: "" });

    const sensitive = usesSensitive(source.subject, source.preheader, source.html_body, source.text_body);
    const windowS = o.dedupeSeconds ?? 300;
    const bucket = Math.floor(Date.now() / 1000 / windowS);
    const dedupeBase = o.test ? null : o.dedupe === undefined ? (o.rideId ? `${o.key}:${o.rideId}` : null) : o.dedupe;

    for (const p of people) {
      if (!p.to || !EMAIL_RE.test(p.to)) {
        if (logOk) await insertRow(db, o, source.id, { userId: p.userId, to: p.to || "(none)", subject: "(not sent)" }, "skipped", "No email address is saved for this person.", null, null, null).catch(() => null);
        result.skipped++;
        continue;
      }
      const values: Record<string, unknown> = { ...base };
      if (!("recipient_name" in values) || !values.recipient_name) values.recipient_name = p.first || "there";
      if (needsWallet && p.userId) {
        const w = (await db.query("select balance, currency from app.wallets where user_id = $1 order by kind limit 1", [p.userId]).catch(() => ({ rows: [] as { balance?: unknown; currency?: unknown }[] }))).rows[0];
        values.wallet_balance = w ? money(w.balance, w.currency) : "";
      }
      let r = renderEmail(source, values, brand);
      if (!r.ok && def?.locked && source.id !== null) r = renderEmail(builtIn(o.key)!, values, brand); // never leave people locked out
      const idem = crypto.randomUUID();
      if (!r.ok) {
        if (logOk) await insertRow(db, o, source.id, { userId: p.userId, to: p.to, subject: "(not sent)" }, "failed", r.error, idem, null, null).catch(() => null);
        result.failed++; result.error = r.error;
        continue;
      }
      const email: RenderedEmail = r.email;
      const masked = sensitive ? renderEmail(source, values, brand, { mask: true }) : null;
      const shownSubject = masked && masked.ok ? masked.email.subject : email.subject;
      let id: number | null = null;
      if (logOk) {
        try {
          id = await insertRow(db, o, source.id,
            { userId: p.userId, to: p.to, subject: shownSubject, html: sensitive ? null : email.html, text: sensitive ? null : email.text, sensitive },
            "queued", null, idem, dedupeBase && p.userId ? `${dedupeBase}:${p.userId}` : dedupeBase && o.to ? `${dedupeBase}:${o.to.toLowerCase()}` : null, bucket);
          if (id === null) { result.skipped++; continue; } // the same email went to this person a moment ago
        } catch (e) { console.error("email log", (e as Error).message); logOk = false; }
      }
      const t = await deliverEmail(db, env.SETTINGS_ENCRYPTION_KEY, { to: p.to, subject: email.subject, html: email.html, text: email.text, idempotencyKey: idem });
      if (t.sent) result.sent++; else { result.failed++; result.error = t.error; }
      if (logOk && id !== null) {
        await db.query(
          t.sent
            ? "update app.email_deliveries set status = 'sent', attempts = attempts + 1, provider_id = $2, provider_status = $3, sent_at = now(), reason = null where id = $1"
            : `update app.email_deliveries set status = 'failed', attempts = attempts + 1, reason = $2, provider_status = $3, retryable = ($4 and not $5),
                      next_retry_at = case when ($4 and not $5) then now() + interval '1 minute' end where id = $1`,
          t.sent ? [id, t.providerId ?? null, t.status ?? null] : [id, String(t.error ?? "Failed").slice(0, 300), t.status ?? null, Boolean(t.retryable), sensitive],
        ).catch((e) => console.error("email log update", (e as Error).message));
      }
    }
    return result;
  } catch (e) {
    console.error("notifyEmail", o.key, (e as Error).message);
    return { ...result, error: (e as Error).message };
  }
}

async function insertRow(db: Client, o: NotifyEmailOpts, templateId: number | null,
  it: { userId: number | null; to: string; subject: string; html?: string | null; text?: string | null; sensitive?: boolean },
  status: string, reason: string | null, idemKey: string | null, dedupeKey: string | null, bucket: number | null): Promise<number | null> {
  const r = await db.query(
    `insert into app.email_deliveries (template_id, template_key, is_test, sent_by, user_id, to_email, ride_id, subject, html_body, text_body, sensitive, status, reason, idempotency_key, dedupe_key, dedupe_bucket)
     values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16) on conflict do nothing returning id`,
    [templateId, o.key, Boolean(o.test), o.test?.adminId ?? null, it.userId, it.to || "(none)", o.rideId ?? null, it.subject, it.html ?? null, it.text ?? null, Boolean(it.sensitive),
      status, reason, idemKey ?? crypto.randomUUID(), dedupeKey, bucket]);
  return r.rows[0] ? Number(r.rows[0].id) : null;
}

/**
 * Every minute: resend emails the provider could not take because of a problem that can clear by itself
 * (network, 429, 5xx). At most 3 tries (after about 1, 5 and 15 minutes). The same idempotency key is reused so an email
 * that actually went through the first time is not delivered twice. Emails with a code or secure link are never retried.
 */
export async function retryEmails(db: Client, env: Bindings): Promise<number> {
  let resent = 0;
  try {
    const due = (await db.query(
      `update app.email_deliveries d set next_retry_at = now() + interval '5 minutes'
        where d.id in (select id from app.email_deliveries
                        where status = 'failed' and retryable and not sensitive and not is_test and attempts < ${MAX_ATTEMPTS}
                          and html_body is not null and next_retry_at <= now() and created_at > now() - interval '1 hour'
                        order by next_retry_at limit 50 for update skip locked)
       returning d.id, d.to_email, d.subject, d.html_body, d.text_body, d.idempotency_key, d.attempts`)).rows;
    for (const r of due) {
      const t = await deliverEmail(db, env.SETTINGS_ENCRYPTION_KEY, { to: String(r.to_email), subject: String(r.subject), html: String(r.html_body), text: r.text_body ?? undefined, idempotencyKey: String(r.idempotency_key) });
      if (t.sent) {
        resent++;
        await db.query("update app.email_deliveries set status = 'sent', attempts = attempts + 1, provider_id = $2, provider_status = $3, sent_at = now(), reason = null, retryable = false, next_retry_at = null where id = $1", [r.id, t.providerId ?? null, t.status ?? null]);
      } else {
        const n = Number(r.attempts) + 1, again = Boolean(t.retryable) && n < MAX_ATTEMPTS;
        await db.query(
          `update app.email_deliveries set attempts = attempts + 1, reason = $2, provider_status = $3, retryable = $4,
                  next_retry_at = case when $4 then now() + $5::interval end where id = $1`,
          [r.id, String(t.error ?? "Failed").slice(0, 300), t.status ?? null, again, RETRY_DELAYS[Math.min(n - 1, RETRY_DELAYS.length - 1)]]);
      }
    }
  } catch (e) { console.error("email retry", (e as Error).message); }
  return resent;
}

/**
 * Creates the built-in templates that are missing. Existing rows, including edited ones, are never touched.
 * The password-reset template starts ON (same behaviour as before). Everything else starts OFF, so merging changes nothing
 * a passenger or driver receives.
 */
export async function ensureEmailTemplates(db: Client): Promise<number> {
  const have = new Set((await db.query("select key from app.email_templates where deleted_at is null")).rows.map((r) => String(r.key)));
  const missing = EMAIL_EVENTS.filter((e) => !have.has(e.key));
  if (!missing.length) return 0;
  const params: unknown[] = [];
  const tuples = missing.map((e) => {
    const vars = [...new Set([...placeholders(e.subject).names, ...placeholders(e.html).names, ...placeholders(e.text).names])].filter((n) => isVar(n));
    const status = e.wired && !e.fresh ? "active" : "inactive";
    params.push(e.key, e.name, e.category, e.audience, e.subject, e.preheader, e.html, e.text, vars, status);
    const n = params.length;
    return `($${n - 9},$${n - 8},$${n - 7},$${n - 6},$${n - 5},$${n - 4},$${n - 3},$${n - 2},$${n - 1}::text[],$${n},true)`;
  });
  const ins = (await db.query(
    `insert into app.email_templates (key, name, category, audience, subject, preheader, html_body, text_body, variables, status, is_system) values ${tuples.join(",")}
     on conflict do nothing returning id, key, name, category, audience, subject, preheader, html_body, text_body, status`, params)).rows;
  for (const r of ins) {
    await db.query("insert into app.email_template_versions (template_id, version, snapshot, note) values ($1, 1, $2::jsonb, 'Built-in default') on conflict do nothing",
      [r.id, JSON.stringify({ key: r.key, name: r.name, category: r.category, audience: r.audience, subject: r.subject, preheader: r.preheader, html_body: r.html_body, text_body: r.text_body, status: r.status })]);
  }
  return ins.length;
}
