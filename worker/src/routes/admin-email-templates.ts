import { Hono, type Context } from "hono";
import { z } from "zod";
import type { AppEnv } from "../env";
import { audit, guard } from "../lib/permissions";
import { readBody, validationFailed } from "../lib/legacy";
import { ensureEmailTemplates, loadBrand, notifyEmail } from "../lib/email-delivery";
import {
  AUDIENCES, CATEGORIES, EMAIL_EVENT_BY_KEY, VARIABLES, normaliseBrand, renderEmail, sampleValues, usesSensitive, validateEmailTemplate,
  type Scheme,
} from "../lib/email-templates";

export const adminEmailTemplateRoutes = new Hono<AppEnv>();
type C = Context<AppEnv>;

const idParam = (c: C) => { const n = Number(c.req.param("id")); return Number.isInteger(n) && n > 0 ? n : null; };
const notFound = (c: C) => c.json({ message: "Not found", status: 404 }, 404);
const num = (v: unknown, d: number, min: number, max: number) => { const n = Number(v); return Number.isFinite(n) ? Math.min(max, Math.max(min, Math.trunc(n))) : d; };
const blank = (v: unknown) => (typeof v === "string" && v.trim() ? v.trim() : null);

const COLS = "id, key, name, category, audience, subject, preheader, html_body, text_body, variables, status, is_system, version, created_at, updated_at";
const LIST_COLS = "id, key, name, category, audience, subject, variables, status, is_system, version, created_at, updated_at";
const view = (r: Record<string, unknown>) => {
  const def = EMAIL_EVENT_BY_KEY.get(String(r.key));
  return {
    ...r, connected: def ? def.wired : false, locked: Boolean(def?.locked),
    connection_note: def?.note ?? (def ? null : "A custom template: no event sends it automatically. Use Send test to deliver it to one person."),
  };
};

const bodySchema = z.object({
  key: z.string().trim().max(80).optional(),
  name: z.string().trim(), category: z.string().trim(), audience: z.string().trim(),
  subject: z.string(), preheader: z.string().nullable().optional(), html_body: z.string(), text_body: z.string(),
});
type Parsed = { errors: Record<string, string[]>; data?: undefined } | { errors?: undefined; data: z.infer<typeof bodySchema> };
const parse = async (c: C): Promise<Parsed> => {
  const p = bodySchema.safeParse(await readBody(c));
  if (!p.success) { const e: Record<string, string[]> = {}; for (const i of p.error.issues) (e[String(i.path[0] ?? "body")] ??= []).push("Check this field."); return { errors: e }; }
  return { data: p.data };
};
const snapshot = (t: Record<string, unknown>) => ({ key: t.key, name: t.name, category: t.category, audience: t.audience, subject: t.subject, preheader: t.preheader, html_body: t.html_body, text_body: t.text_body, status: t.status });

// ---- reference data for the Admin form ----
adminEmailTemplateRoutes.get("/admin/email-templates/meta", ...guard("email_template list"), async (c) => {
  return c.json({
    variables: Object.entries(VARIABLES).map(([name, v]) => ({ name, label: v.label, sample: v.sample, sensitive: Boolean(v.sensitive), link: Boolean(v.url) })),
    categories: Object.entries(CATEGORIES).map(([id, label]) => ({ id, label })),
    audiences: AUDIENCES,
    brand: await loadBrand(c.get("db")),
    allowed_html: "p, br, hr, h1-h3, strong, b, em, i, u, small, span, div, center, a, ul, ol, li, table, thead, tbody, tr, td, th, img. Links must be https://, mailto:, tel: or {{action_url}}. Images must be https:// and have alt text.",
  });
});

// ---- branding (logo, accent colour, footer) shared by every email ----
adminEmailTemplateRoutes.get("/admin/email-branding", ...guard("email_template list"), async (c) => c.json({ data: await loadBrand(c.get("db")) }));

adminEmailTemplateRoutes.put("/admin/email-branding", ...guard("email_template edit"), async (c) => {
  const b = await readBody(c);
  const errors: Record<string, string[]> = {};
  if (b.logo_url && !/^https:\/\/[^\s<>"']+$/.test(String(b.logo_url))) errors.logo_url = ["The logo must be a plain https link."];
  if (b.accent && !/^#[0-9a-fA-F]{6}$/.test(String(b.accent))) errors.accent = ["Use a colour like #FF8A00."];
  if (b.support_email && !/^[^\s@<>"']+@[^\s@<>"']+\.[^\s@<>"']+$/.test(String(b.support_email))) errors.support_email = ["Enter a valid email address."];
  if (Object.keys(errors).length) return validationFailed(c, errors);
  const brand = normaliseBrand(b);
  const db = c.get("db");
  const before = await loadBrand(db);
  await db.query("insert into app.settings (key, value) values ('email_brand', $1::jsonb) on conflict (key) do update set value = excluded.value", [JSON.stringify(brand)]);
  await audit(c, "email_branding_edit", "email_brand", { changed: (Object.keys(brand) as (keyof typeof brand)[]).filter((k) => brand[k] !== before[k]) });
  return c.json({ message: "Saved. It applies to the next email.", data: brand });
});

// ---- list / search / filter ----
adminEmailTemplateRoutes.get("/admin/email-templates", ...guard("email_template list"), async (c) => {
  const db = c.get("db");
  await ensureEmailTemplates(db).catch((e) => console.error("seed email templates", (e as Error).message));
  const q = c.req.query();
  const where = ["deleted_at is null"]; const args: unknown[] = [];
  const add = (sql: string, v: unknown) => { args.push(v); where.push(sql.replace("?", `$${args.length}`)); };
  if (q.q?.trim()) {
    args.push(`%${q.q.trim().replace(/[%_\\]/g, "\\$&")}%`);
    const n = args.length;
    where.push(`(key ilike $${n} or name ilike $${n} or subject ilike $${n} or html_body ilike $${n})`);
  }
  if (q.category && CATEGORIES[q.category]) add("category = ?", q.category);
  if ((AUDIENCES as readonly string[]).includes(q.audience ?? "")) add("audience = ?", q.audience);
  if (["active", "inactive", "archived"].includes(q.status ?? "")) add("status = ?", q.status);
  else if (q.status !== "all") where.push("status <> 'archived'");
  const limit = num(q.limit, 50, 1, 100), page = num(q.page, 1, 1, 10000);
  const rows = (await db.query(`select ${LIST_COLS}, count(*) over()::int as total from app.email_templates where ${where.join(" and ")} order by audience, category, name limit ${limit} offset ${(page - 1) * limit}`, args)).rows;
  return c.json({ data: rows.map(({ total, ...r }) => view(r)), total: rows[0]?.total ?? 0, page, per_page: limit });
});

// ---- preview (nothing is saved or sent) ----
adminEmailTemplateRoutes.post("/admin/email-templates/preview", ...guard("email_template list"), async (c) => {
  const b = await readBody(c);
  const input = { name: "Preview", category: "ride", audience: "passenger", subject: String(b.subject ?? ""), preheader: blank(b.preheader), html_body: String(b.html_body ?? ""), text_body: String(b.text_body ?? "x") };
  const v = validateEmailTemplate(input, { checkKey: false });
  const errors = { ...v.errors }; delete errors.name; delete errors.category; delete errors.audience;
  const values = { ...sampleValues(), ...(typeof b.values === "object" && b.values ? b.values as Record<string, string> : {}) };
  const scheme: Scheme = b.scheme === "dark" ? "dark" : "light";
  const valid = Object.keys(errors).length === 0;
  const r = valid ? renderEmail(input, values, await loadBrand(c.get("db")), { scheme }) : null;
  return c.json({
    valid, errors, variables: v.variables, uses_sensitive: usesSensitive(input.subject, input.html_body, input.text_body),
    subject: r?.ok ? r.email.subject : null, preheader: r?.ok ? r.email.preheader : null, html: r?.ok ? r.email.html : null, text: r?.ok ? r.email.text : null,
    note: "Email apps handle dark mode differently: some follow the message's own colours, some invert them. This preview shows both a light and a dark look; your own inbox is the final check.",
  });
});

adminEmailTemplateRoutes.get("/admin/email-templates/:id", ...guard("email_template list"), async (c) => {
  const id = idParam(c); if (!id) return notFound(c);
  const db = c.get("db");
  const t = (await db.query(`select ${COLS} from app.email_templates where id = $1 and deleted_at is null`, [id])).rows[0];
  if (!t) return notFound(c);
  const versions = (await db.query("select version, note, snapshot, created_at, changed_by from app.email_template_versions where template_id = $1 order by version desc limit 20", [id])).rows;
  return c.json({ data: view(t), versions });
});

// ---- create / edit ----
adminEmailTemplateRoutes.post("/admin/email-templates", ...guard("email_template add"), async (c) => {
  const p = await parse(c); if (p.errors) return validationFailed(c, p.errors);
  const db = c.get("db");
  const v = validateEmailTemplate(p.data);
  if (Object.keys(v.errors).length) return validationFailed(c, v.errors);
  const d = p.data, me = c.get("user").id;
  try {
    await db.query("begin");
    const t = (await db.query(
      `insert into app.email_templates (key, name, category, audience, subject, preheader, html_body, text_body, variables, status, created_by, updated_by)
       values ($1,$2,$3,$4,$5,$6,$7,$8,$9,'inactive',$10,$10) returning ${COLS}`,
      [d.key, d.name, d.category, d.audience, d.subject.trim(), blank(d.preheader), d.html_body.trim(), d.text_body.trim(), v.variables, me])).rows[0];
    await db.query("insert into app.email_template_versions (template_id, version, snapshot, note, changed_by) values ($1,1,$2::jsonb,'Created',$3)", [t.id, JSON.stringify(snapshot(t)), me]);
    await audit(c, "email_template_add", String(t.id), { key: t.key });
    await db.query("commit");
    return c.json({ message: "Created. It is switched off until you turn it on.", data: view(t) }, 201);
  } catch (e) {
    await db.query("rollback").catch(() => undefined);
    if ((e as { code?: string }).code === "23505") return validationFailed(c, { key: ["That key is already used by another template."] });
    throw e;
  }
});

adminEmailTemplateRoutes.put("/admin/email-templates/:id", ...guard("email_template edit"), async (c) => {
  const id = idParam(c); if (!id) return notFound(c);
  const p = await parse(c); if (p.errors) return validationFailed(c, p.errors);
  const db = c.get("db"), me = c.get("user").id;
  const cur = (await db.query(`select ${COLS} from app.email_templates where id = $1 and deleted_at is null`, [id])).rows[0];
  if (!cur) return notFound(c);
  const d = p.data;
  // A built-in template is tied to an event in the Worker: its key, audience and category stay as they are.
  if (cur.is_system && (d.key && d.key !== cur.key || d.audience !== cur.audience || d.category !== cur.category)) {
    return validationFailed(c, { key: ["A built-in template's key, audience and category cannot be changed. Edit the text, or duplicate it."] });
  }
  const v = validateEmailTemplate({ ...d, key: cur.key });
  if (Object.keys(v.errors).length) return validationFailed(c, v.errors);
  try {
    await db.query("begin");
    const t = (await db.query(
      `update app.email_templates set name=$2, category=$3, audience=$4, subject=$5, preheader=$6, html_body=$7, text_body=$8, variables=$9, version=version+1, updated_by=$10
        where id=$1 returning ${COLS}`,
      [id, d.name, cur.is_system ? cur.category : d.category, cur.is_system ? cur.audience : d.audience, d.subject.trim(), blank(d.preheader), d.html_body.trim(), d.text_body.trim(), v.variables, me])).rows[0];
    await db.query("insert into app.email_template_versions (template_id, version, snapshot, note, changed_by) values ($1,$2,$3::jsonb,'Edited',$4)", [id, t.version, JSON.stringify(snapshot(t)), me]);
    const a = snapshot(cur) as Record<string, unknown>, b = snapshot(t) as Record<string, unknown>;
    await audit(c, "email_template_edit", String(id), { key: t.key, version: t.version, changed: Object.keys(b).filter((k) => a[k] !== b[k]) });
    await db.query("commit");
    return c.json({ message: "Saved", data: view(t) });
  } catch (e) { await db.query("rollback").catch(() => undefined); throw e; }
});

adminEmailTemplateRoutes.post("/admin/email-templates/:id/status", ...guard("email_template edit"), async (c) => {
  const id = idParam(c); if (!id) return notFound(c);
  const s = z.object({ status: z.enum(["active", "inactive", "archived"]) }).safeParse(await readBody(c));
  if (!s.success) return validationFailed(c, { status: ["Choose active, inactive or archived."] });
  const db = c.get("db");
  const cur = (await db.query("select key from app.email_templates where id = $1 and deleted_at is null", [id])).rows[0];
  if (!cur) return notFound(c);
  if (EMAIL_EVENT_BY_KEY.get(String(cur.key))?.locked && s.data.status !== "active") {
    return c.json({ message: "This email is always on: people could not reset a forgotten password without it. Edit its wording instead.", status: 409 }, 409);
  }
  const r = (await db.query("update app.email_templates set status = $2, updated_by = $3 where id = $1 returning key, status", [id, s.data.status, c.get("user").id])).rows[0];
  await audit(c, "email_template_status", String(id), { key: r.key, status: r.status });
  return c.json({ message: r.status === "active" ? "Switched on" : r.status === "archived" ? "Archived" : "Switched off", status: r.status });
});

adminEmailTemplateRoutes.post("/admin/email-templates/:id/duplicate", ...guard("email_template add"), async (c) => {
  const id = idParam(c); if (!id) return notFound(c);
  const db = c.get("db"), me = c.get("user").id;
  const src = (await db.query(`select ${COLS} from app.email_templates where id = $1 and deleted_at is null`, [id])).rows[0];
  if (!src) return notFound(c);
  for (let n = 1; n <= 20; n++) {
    const key = `${String(src.key).slice(0, 70)}_copy${n === 1 ? "" : n}`;
    try {
      await db.query("begin");
      const t = (await db.query(
        `insert into app.email_templates (key, name, category, audience, subject, preheader, html_body, text_body, variables, status, is_system, created_by, updated_by)
         values ($1,$2,$3,$4,$5,$6,$7,$8,$9,'inactive',false,$10,$10) returning ${COLS}`,
        [key, `${String(src.name).slice(0, 110)} (copy)`, src.category, src.audience, src.subject, src.preheader, src.html_body, src.text_body, src.variables, me])).rows[0];
      await db.query("insert into app.email_template_versions (template_id, version, snapshot, note, changed_by) values ($1,1,$2::jsonb,$3,$4)", [t.id, JSON.stringify(snapshot(t)), `Duplicated from ${src.key}`, me]);
      await audit(c, "email_template_duplicate", String(t.id), { from: src.key, key });
      await db.query("commit");
      return c.json({ message: "Duplicated. The copy is switched off.", data: view(t) }, 201);
    } catch (e) {
      await db.query("rollback").catch(() => undefined);
      if ((e as { code?: string }).code !== "23505") throw e;
    }
  }
  return c.json({ message: "Could not find a free key for the copy.", status: 409 }, 409);
});

/** Puts an older version's text back as a NEW version (history is never rewritten). */
adminEmailTemplateRoutes.post("/admin/email-templates/:id/restore", ...guard("email_template edit"), async (c) => {
  const id = idParam(c); if (!id) return notFound(c);
  const s = z.object({ version: z.number().int().positive() }).safeParse(await readBody(c));
  if (!s.success) return validationFailed(c, { version: ["Choose a version."] });
  const db = c.get("db"), me = c.get("user").id;
  const cur = (await db.query(`select ${COLS} from app.email_templates where id = $1 and deleted_at is null`, [id])).rows[0];
  if (!cur) return notFound(c);
  const old = (await db.query("select snapshot from app.email_template_versions where template_id = $1 and version = $2", [id, s.data.version])).rows[0]?.snapshot as Record<string, string | null> | undefined;
  if (!old) return notFound(c);
  const v = validateEmailTemplate({ name: cur.name, category: cur.category, audience: cur.audience, subject: String(old.subject ?? ""), preheader: old.preheader ?? null, html_body: String(old.html_body ?? ""), text_body: String(old.text_body ?? "") }, { checkKey: false });
  if (Object.keys(v.errors).length) return validationFailed(c, v.errors);
  try {
    await db.query("begin");
    const t = (await db.query(
      `update app.email_templates set subject=$2, preheader=$3, html_body=$4, text_body=$5, variables=$6, version=version+1, updated_by=$7 where id=$1 returning ${COLS}`,
      [id, old.subject, old.preheader ?? null, old.html_body, old.text_body, v.variables, me])).rows[0];
    await db.query("insert into app.email_template_versions (template_id, version, snapshot, note, changed_by) values ($1,$2,$3::jsonb,$4,$5)", [id, t.version, JSON.stringify(snapshot(t)), `Restored version ${s.data.version}`, me]);
    await audit(c, "email_template_restore", String(id), { key: t.key, restored: s.data.version, version: t.version });
    await db.query("commit");
    return c.json({ message: `Restored version ${s.data.version} as version ${t.version}.`, data: view(t) });
  } catch (e) { await db.query("rollback").catch(() => undefined); throw e; }
});

adminEmailTemplateRoutes.delete("/admin/email-templates/:id", ...guard("email_template delete"), async (c) => {
  const id = idParam(c); if (!id) return notFound(c);
  const db = c.get("db");
  const t = (await db.query("select key, is_system, status from app.email_templates where id = $1 and deleted_at is null", [id])).rows[0];
  if (!t) return notFound(c);
  if (t.is_system) return c.json({ message: "Built-in templates cannot be deleted. Switch it off or archive it instead.", status: 409 }, 409);
  if (t.status === "active") return c.json({ message: "Switch the template off before deleting it.", status: 409 }, 409);
  await db.query("update app.email_templates set deleted_at = now(), status = 'archived', updated_by = $2 where id = $1", [id, c.get("user").id]);
  await audit(c, "email_template_delete", String(id), { key: t.key });
  return c.json({ message: "Deleted. Its delivery history is kept." });
});

// ---- test send: only to an address that belongs to a DROP account (so this cannot be used to email strangers) ----
adminEmailTemplateRoutes.post("/admin/email-templates/:id/test", ...guard("email_template send"), async (c) => {
  const id = idParam(c); if (!id) return notFound(c);
  const p = z.object({ email: z.string().trim().email("Enter the person's email.") }).safeParse(await readBody(c));
  if (!p.success) return validationFailed(c, { email: ["Enter the person's email."] });
  const db = c.get("db"), me = c.get("user").id;
  const t = (await db.query("select key from app.email_templates where id = $1 and deleted_at is null", [id])).rows[0];
  if (!t) return notFound(c);
  const u = (await db.query("select id, first_name from app.users where lower(email) = lower($1) and deleted_at is null limit 1", [p.data.email])).rows[0];
  if (!u) return c.json({ message: "No account has that email. For safety, test emails go only to addresses that belong to a DROP account (yours is fine).", status: 404 }, 404);
  const recent = Number((await db.query("select count(*)::int as n from app.email_deliveries where is_test and sent_by = $1 and created_at > now() - interval '1 hour'", [me])).rows[0].n);
  if (recent >= 20) return c.json({ message: "You have sent 20 test emails in the last hour. Try again later.", status: 429 }, 429);
  const r = await notifyEmail(db, c.env, { key: t.key, userIds: [Number(u.id)], test: { adminId: me }, vars: { recipient_name: String(u.first_name ?? "").trim() || "there" } });
  await audit(c, "email_template_test", String(id), { key: t.key, to_user: Number(u.id), sent: r.sent });
  return r.sent ? c.json({ message: "Sent with sample values. It should arrive in a minute. Check the spam folder too." }) : c.json({ message: r.error || "The email provider did not accept it.", status: 502 }, 502);
});

// ---- delivery history, failure inspection, statistics ----
adminEmailTemplateRoutes.get("/admin/email-deliveries", ...guard("email_template list"), async (c) => {
  const db = c.get("db"), q = c.req.query();
  const where = ["true"]; const args: unknown[] = [];
  const add = (sql: string, v: unknown) => { args.push(v); where.push(sql.replace("?", `$${args.length}`)); };
  if (["queued", "sent", "failed", "skipped"].includes(q.status ?? "")) add("d.status = ?", q.status);
  if (q.template_key?.trim()) add("d.template_key = ?", q.template_key.trim());
  if (q.q?.trim()) add("(d.to_email ilike ? escape '\\')", `%${q.q.trim().replace(/[%_\\]/g, "\\$&")}%`);
  if (q.tests === "only") where.push("d.is_test"); else if (q.tests !== "include") where.push("not d.is_test");
  if (q.ride_id && Number.isInteger(Number(q.ride_id))) add("d.ride_id = ?", Number(q.ride_id));
  const limit = num(q.limit, 50, 1, 100), page = num(q.page, 1, 1, 100000);
  const rows = (await db.query(
    `select d.id, d.template_key, d.is_test, d.user_id, d.to_email, d.ride_id, d.subject, d.status, d.reason, d.provider_status, d.attempts, d.retryable, d.next_retry_at, d.provider_id, d.sensitive, d.created_at, d.sent_at,
            count(*) over()::int as total
       from app.email_deliveries d
      where ${where.join(" and ")} order by d.created_at desc, d.id desc limit ${limit} offset ${(page - 1) * limit}`, args)).rows;
  return c.json({ data: rows.map(({ total, ...r }) => r), total: rows[0]?.total ?? 0, page, per_page: limit });
});

adminEmailTemplateRoutes.get("/admin/email-deliveries/stats", ...guard("email_template list"), async (c) => {
  const db = c.get("db");
  const days = num(c.req.query("days"), 7, 1, 90);
  const win = "d.created_at > now() - make_interval(days => $1::int) and not d.is_test";
  const totals = (await db.query(`select d.status, count(*)::int as n from app.email_deliveries d where ${win} group by d.status`, [days])).rows;
  const byTemplate = (await db.query(
    `select d.template_key, count(*)::int as total, (count(*) filter (where d.status='sent'))::int as sent, (count(*) filter (where d.status='failed'))::int as failed, (count(*) filter (where d.status='skipped'))::int as skipped
       from app.email_deliveries d where ${win} group by d.template_key order by total desc limit 25`, [days])).rows;
  const byDay = (await db.query(
    `select to_char(date_trunc('day', d.created_at), 'YYYY-MM-DD') as day, (count(*) filter (where d.status='sent'))::int as sent, (count(*) filter (where d.status='failed'))::int as failed, (count(*) filter (where d.status='skipped'))::int as skipped
       from app.email_deliveries d where ${win} group by 1 order by 1`, [days])).rows;
  const reasons = (await db.query(
    `select d.reason, count(*)::int as n from app.email_deliveries d where ${win} and d.status in ('failed','skipped') and d.reason is not null group by d.reason order by n desc limit 10`, [days])).rows;
  const t: Record<string, number> = { sent: 0, failed: 0, skipped: 0, queued: 0 };
  for (const r of totals) t[String(r.status)] = r.n;
  return c.json({
    days, totals: t, by_template: byTemplate, by_day: byDay, reasons,
    note: "Sent means the email provider accepted the email. It does not prove it reached the inbox. Test sends are not counted.",
  });
});

/** One delivery in full, for inspecting a failure: the reason, the provider's answer, the retry state and (when kept) what was sent. */
adminEmailTemplateRoutes.get("/admin/email-deliveries/:id", ...guard("email_template list"), async (c) => {
  const id = idParam(c); if (!id) return notFound(c);
  const d = (await c.get("db").query(
    `select d.id, d.template_id, d.template_key, d.is_test, d.user_id, d.to_email, d.ride_id, d.subject, d.html_body, d.text_body, d.sensitive, d.status, d.reason, d.provider_status,
            d.attempts, d.retryable, d.next_retry_at, d.provider_id, d.dedupe_key, d.created_at, d.sent_at
       from app.email_deliveries d where d.id = $1`, [id])).rows[0];
  if (!d) return notFound(c);
  return c.json({
    data: d,
    explanation: d.status === "failed"
      ? (d.retryable ? `The provider could not take it (${d.provider_status ?? "no answer"}). DROP will try again automatically, up to 3 times.` : "This failure will not clear by itself, so DROP will not retry it. Fix the cause (for example the sending domain or the address), then send a new email.")
      : d.status === "skipped" ? "Nothing was sent on purpose: see the reason." : null,
    body_note: d.sensitive ? "This email carries a code or secure link, so its body is not kept." : null,
  });
});
