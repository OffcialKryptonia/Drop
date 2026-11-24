import { Hono, type Context } from "hono";
import { z } from "zod";
import type { AppEnv } from "../env";
import { audit, guard } from "../lib/permissions";
import { readBody, validationFailed } from "../lib/legacy";
import { ensureSystemTemplates, linkHosts, notify } from "../lib/push-delivery";
import { CATEGORIES, EVENT_BY_KEY, renderText, sampleValues, validateTemplate, VARIABLES, usesSensitive } from "../lib/push-templates";

export const adminPushTemplateRoutes = new Hono<AppEnv>();
type C = Context<AppEnv>;

const idParam = (c: C) => { const n = Number(c.req.param("id")); return Number.isInteger(n) && n > 0 ? n : null; };
const notFound = (c: C) => c.json({ message: "Not found", status: 404 }, 404);
const num = (v: unknown, d: number, min: number, max: number) => { const n = Number(v); return Number.isFinite(n) ? Math.min(max, Math.max(min, Math.trunc(n))) : d; };
const blank = (v: unknown) => (typeof v === "string" && v.trim() ? v.trim() : null);

const COLS = "id, key, name, category, audience, title, body, image_url, deep_link, action_label, variables, status, is_system, version, created_at, updated_at";
const view = (r: Record<string, unknown>) => {
  const def = EVENT_BY_KEY.get(String(r.key));
  return { ...r, connected: def ? def.wired : false, connection_note: def?.note ?? (def ? null : "A custom template: no event sends it automatically. Use Send test to deliver it to one person.") };
};

const bodySchema = z.object({
  key: z.string().trim().max(80).optional(),
  name: z.string().trim(), category: z.string().trim(), audience: z.string().trim(),
  title: z.string(), body: z.string(),
  image_url: z.string().nullable().optional(), deep_link: z.string().nullable().optional(), action_label: z.string().nullable().optional(),
});
type Parsed = { errors: Record<string, string[]>; data?: undefined } | { errors?: undefined; data: z.infer<typeof bodySchema> };
const parse = async (c: C): Promise<Parsed> => {
  const p = bodySchema.safeParse(await readBody(c));
  if (!p.success) { const e: Record<string, string[]> = {}; for (const i of p.error.issues) (e[String(i.path[0] ?? "body")] ??= []).push("Check this field."); return { errors: e }; }
  return { data: p.data };
};
const snapshot = (t: Record<string, unknown>) => ({ key: t.key, name: t.name, category: t.category, audience: t.audience, title: t.title, body: t.body, image_url: t.image_url, deep_link: t.deep_link, action_label: t.action_label, status: t.status });

// ---- reference data for the Admin form ----
adminPushTemplateRoutes.get("/admin/push-templates/meta", ...guard("push_template list"), async (c) => {
  return c.json({
    variables: Object.entries(VARIABLES).map(([name, v]) => ({ name, label: v.label, sample: v.sample, sensitive: Boolean(v.sensitive) })),
    categories: Object.entries(CATEGORIES).map(([id, label]) => ({ id, label })),
    link_hosts: await linkHosts(c.get("db")),
  });
});

// ---- list / search / filter ----
adminPushTemplateRoutes.get("/admin/push-templates", ...guard("push_template list"), async (c) => {
  const db = c.get("db");
  await ensureSystemTemplates(db).catch((e) => console.error("seed push templates", (e as Error).message));
  const q = c.req.query();
  const where = ["deleted_at is null"]; const args: unknown[] = [];
  const add = (sql: string, v: unknown) => { args.push(v); where.push(sql.replace("?", `$${args.length}`)); };
  if (q.q?.trim()) {
    args.push(`%${q.q.trim().replace(/[%_\\]/g, "\\$&")}%`);
    const n = args.length;
    where.push(`(key ilike $${n} or name ilike $${n} or title ilike $${n} or body ilike $${n})`);
  }
  if (q.category && CATEGORIES[q.category]) add("category = ?", q.category);
  if (["passenger", "driver", "all"].includes(q.audience ?? "")) add("audience = ?", q.audience);
  if (["active", "inactive", "archived"].includes(q.status ?? "")) add("status = ?", q.status);
  else if (q.status !== "all") where.push("status <> 'archived'");
  const limit = num(q.limit, 50, 1, 100), page = num(q.page, 1, 1, 10000);
  const rows = (await db.query(`select ${COLS}, count(*) over()::int as total from app.push_templates where ${where.join(" and ")} order by audience, category, name limit ${limit} offset ${(page - 1) * limit}`, args)).rows;
  return c.json({ data: rows.map(({ total, ...r }) => view(r)), total: rows[0]?.total ?? 0, page, per_page: limit });
});

adminPushTemplateRoutes.post("/admin/push-templates/preview", ...guard("push_template list"), async (c) => {
  const b = await readBody(c);
  const v = validateTemplate({ name: "Preview", category: "ride", audience: "all", title: String(b.title ?? ""), body: String(b.body ?? ""), image_url: blank(b.image_url), deep_link: blank(b.deep_link), action_label: blank(b.action_label) },
    { allowedLinkHosts: await linkHosts(c.get("db")), checkKey: false });
  const values = { ...sampleValues(), ...(typeof b.values === "object" && b.values ? b.values as Record<string, string> : {}) };
  const errors = { ...v.errors }; delete errors.name; delete errors.category; delete errors.audience;
  return c.json({
    valid: Object.keys(errors).length === 0, errors, variables: v.variables,
    title: renderText(String(b.title ?? ""), values), body: renderText(String(b.body ?? ""), values),
    deep_link: b.deep_link ? renderText(String(b.deep_link), values, { encode: true }) : null,
    uses_sensitive: usesSensitive(String(b.title ?? ""), String(b.body ?? "")),
  });
});

adminPushTemplateRoutes.get("/admin/push-templates/:id", ...guard("push_template list"), async (c) => {
  const id = idParam(c); if (!id) return notFound(c);
  const db = c.get("db");
  const t = (await db.query(`select ${COLS} from app.push_templates where id = $1 and deleted_at is null`, [id])).rows[0];
  if (!t) return notFound(c);
  const versions = (await db.query("select version, note, snapshot, created_at, changed_by from app.push_template_versions where template_id = $1 order by version desc limit 20", [id])).rows;
  return c.json({ data: view(t), versions });
});

// ---- create / edit ----
adminPushTemplateRoutes.post("/admin/push-templates", ...guard("push_template add"), async (c) => {
  const p = await parse(c); if (p.errors) return validationFailed(c, p.errors);
  const db = c.get("db");
  const v = validateTemplate(p.data, { allowedLinkHosts: await linkHosts(db) });
  if (Object.keys(v.errors).length) return validationFailed(c, v.errors);
  const d = p.data, me = c.get("user").id;
  try {
    await db.query("begin");
    const t = (await db.query(
      `insert into app.push_templates (key, name, category, audience, title, body, image_url, deep_link, action_label, variables, status, created_by, updated_by)
       values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,'inactive',$11,$11) returning ${COLS}`,
      [d.key, d.name, d.category, d.audience, d.title.trim(), d.body.trim(), blank(d.image_url), blank(d.deep_link), blank(d.action_label), v.variables, me])).rows[0];
    await db.query("insert into app.push_template_versions (template_id, version, snapshot, note, changed_by) values ($1,1,$2::jsonb,'Created',$3)", [t.id, JSON.stringify(snapshot(t)), me]);
    await audit(c, "push_template_add", String(t.id), { key: t.key });
    await db.query("commit");
    return c.json({ message: "Created. It is switched off until you turn it on.", data: view(t) }, 201);
  } catch (e) {
    await db.query("rollback").catch(() => undefined);
    if ((e as { code?: string }).code === "23505") return validationFailed(c, { key: ["That key is already used by another template."] });
    throw e;
  }
});

adminPushTemplateRoutes.put("/admin/push-templates/:id", ...guard("push_template edit"), async (c) => {
  const id = idParam(c); if (!id) return notFound(c);
  const p = await parse(c); if (p.errors) return validationFailed(c, p.errors);
  const db = c.get("db"), me = c.get("user").id;
  const cur = (await db.query(`select ${COLS} from app.push_templates where id = $1 and deleted_at is null`, [id])).rows[0];
  if (!cur) return notFound(c);
  const d = p.data;
  // A built-in template is tied to an event in the Worker: its key, audience and category stay as they are.
  if (cur.is_system && (d.key && d.key !== cur.key || d.audience !== cur.audience || d.category !== cur.category)) {
    return validationFailed(c, { key: ["A built-in template's key, audience and category cannot be changed. Edit the text, or duplicate it."] });
  }
  const v = validateTemplate({ ...d, key: cur.key }, { allowedLinkHosts: await linkHosts(db) });
  if (Object.keys(v.errors).length) return validationFailed(c, v.errors);
  try {
    await db.query("begin");
    const t = (await db.query(
      `update app.push_templates set name=$2, category=$3, audience=$4, title=$5, body=$6, image_url=$7, deep_link=$8, action_label=$9, variables=$10, version=version+1, updated_by=$11
        where id=$1 returning ${COLS}`,
      [id, d.name, cur.is_system ? cur.category : d.category, cur.is_system ? cur.audience : d.audience, d.title.trim(), d.body.trim(), blank(d.image_url), blank(d.deep_link), blank(d.action_label), v.variables, me])).rows[0];
    await db.query("insert into app.push_template_versions (template_id, version, snapshot, note, changed_by) values ($1,$2,$3::jsonb,'Edited',$4)", [id, t.version, JSON.stringify(snapshot(t)), me]);
    await audit(c, "push_template_edit", String(id), { key: t.key, version: t.version, changed: Object.keys(snapshot(t)).filter((k) => (snapshot(cur) as Record<string, unknown>)[k] !== (snapshot(t) as Record<string, unknown>)[k]) });
    await db.query("commit");
    return c.json({ message: "Saved", data: view(t) });
  } catch (e) { await db.query("rollback").catch(() => undefined); throw e; }
});

adminPushTemplateRoutes.post("/admin/push-templates/:id/status", ...guard("push_template edit"), async (c) => {
  const id = idParam(c); if (!id) return notFound(c);
  const s = z.object({ status: z.enum(["active", "inactive", "archived"]) }).safeParse(await readBody(c));
  if (!s.success) return validationFailed(c, { status: ["Choose active, inactive or archived."] });
  const db = c.get("db");
  const r = (await db.query("update app.push_templates set status = $2, updated_by = $3 where id = $1 and deleted_at is null returning key, status", [id, s.data.status, c.get("user").id])).rows[0];
  if (!r) return notFound(c);
  await audit(c, "push_template_status", String(id), { key: r.key, status: r.status });
  return c.json({ message: r.status === "active" ? "Switched on" : r.status === "archived" ? "Archived" : "Switched off", status: r.status });
});

adminPushTemplateRoutes.post("/admin/push-templates/:id/duplicate", ...guard("push_template add"), async (c) => {
  const id = idParam(c); if (!id) return notFound(c);
  const db = c.get("db"), me = c.get("user").id;
  const src = (await db.query(`select ${COLS} from app.push_templates where id = $1 and deleted_at is null`, [id])).rows[0];
  if (!src) return notFound(c);
  for (let n = 1; n <= 20; n++) {
    const key = `${String(src.key).slice(0, 70)}_copy${n === 1 ? "" : n}`;
    try {
      await db.query("begin");
      const t = (await db.query(
        `insert into app.push_templates (key, name, category, audience, title, body, image_url, deep_link, action_label, variables, status, is_system, created_by, updated_by)
         values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,'inactive',false,$11,$11) returning ${COLS}`,
        [key, `${String(src.name).slice(0, 110)} (copy)`, src.category, src.audience, src.title, src.body, src.image_url, src.deep_link, src.action_label, src.variables, me])).rows[0];
      await db.query("insert into app.push_template_versions (template_id, version, snapshot, note, changed_by) values ($1,1,$2::jsonb,$3,$4)", [t.id, JSON.stringify(snapshot(t)), `Duplicated from ${src.key}`, me]);
      await audit(c, "push_template_duplicate", String(t.id), { from: src.key, key });
      await db.query("commit");
      return c.json({ message: "Duplicated. The copy is switched off.", data: view(t) }, 201);
    } catch (e) {
      await db.query("rollback").catch(() => undefined);
      if ((e as { code?: string }).code !== "23505") throw e;
    }
  }
  return c.json({ message: "Could not find a free key for the copy.", status: 409 }, 409);
});

adminPushTemplateRoutes.delete("/admin/push-templates/:id", ...guard("push_template delete"), async (c) => {
  const id = idParam(c); if (!id) return notFound(c);
  const db = c.get("db");
  const t = (await db.query("select key, is_system, status from app.push_templates where id = $1 and deleted_at is null", [id])).rows[0];
  if (!t) return notFound(c);
  if (t.is_system) return c.json({ message: "Built-in templates cannot be deleted. Switch it off or archive it instead.", status: 409 }, 409);
  if (t.status === "active") return c.json({ message: "Switch the template off before deleting it.", status: 409 }, 409);
  await db.query("update app.push_templates set deleted_at = now(), status = 'archived', updated_by = $2 where id = $1", [id, c.get("user").id]);
  await audit(c, "push_template_delete", String(id), { key: t.key });
  return c.json({ message: "Deleted. Its delivery history is kept." });
});

// ---- test send ----
adminPushTemplateRoutes.post("/admin/push-templates/:id/test", ...guard("push_template send"), async (c) => {
  const id = idParam(c); if (!id) return notFound(c);
  const p = z.object({ email: z.string().trim().email("Enter the person's email.") }).safeParse(await readBody(c));
  if (!p.success) return validationFailed(c, { email: ["Enter the person's email."] });
  const db = c.get("db"), me = c.get("user").id;
  const t = (await db.query("select key from app.push_templates where id = $1 and deleted_at is null", [id])).rows[0];
  if (!t) return notFound(c);
  const u = (await db.query("select id, player_id from app.users where lower(email) = lower($1) and deleted_at is null", [p.data.email])).rows[0];
  if (!u) return c.json({ message: "No account has that email.", status: 404 }, 404);
  const recent = Number((await db.query("select count(*)::int as n from app.push_deliveries where is_test and sent_by = $1 and created_at > now() - interval '1 hour'", [me])).rows[0].n);
  if (recent >= 20) return c.json({ message: "You have sent 20 test notifications in the last hour. Try again later.", status: 429 }, 429);
  if (!u.player_id) return c.json({ message: "That person has not allowed notifications on a phone with the new app yet.", status: 409 }, 409);
  const r = await notify(db, c.env, { key: t.key, userIds: [Number(u.id)], test: { adminId: me }, data: { type: "test" } });
  await audit(c, "push_template_test", String(id), { key: t.key, to_user: Number(u.id), sent: r.sent });
  return r.sent ? c.json({ message: "Sent with sample values. It should arrive in a few seconds." }) : c.json({ message: r.error || "OneSignal did not accept it.", status: 502 }, 502);
});

// ---- delivery history, statistics, failures ----
adminPushTemplateRoutes.get("/admin/push-deliveries", ...guard("push_template list"), async (c) => {
  const db = c.get("db"), q = c.req.query();
  const where = ["true"]; const args: unknown[] = [];
  const add = (sql: string, v: unknown) => { args.push(v); where.push(sql.replace("?", `$${args.length}`)); };
  if (["queued", "sent", "failed", "skipped"].includes(q.status ?? "")) add("d.status = ?", q.status);
  if (q.template_key?.trim()) add("d.template_key = ?", q.template_key.trim());
  if (q.q?.trim()) add("(u.email ilike ? escape '\\')", `%${q.q.trim().replace(/[%_\\]/g, "\\$&")}%`);
  if (q.tests === "only") where.push("d.is_test"); else if (q.tests !== "include") where.push("not d.is_test");
  if (q.ride_id && Number.isInteger(Number(q.ride_id))) add("d.ride_id = ?", Number(q.ride_id));
  const limit = num(q.limit, 50, 1, 100), page = num(q.page, 1, 1, 100000);
  const rows = (await db.query(
    `select d.id, d.template_key, d.is_test, d.user_id, u.email, d.ride_id, d.title, d.body, d.deep_link, d.status, d.reason, d.attempts, d.retryable, d.next_retry_at, d.provider_id, d.created_at, d.sent_at,
            count(*) over()::int as total
       from app.push_deliveries d left join app.users u on u.id = d.user_id
      where ${where.join(" and ")} order by d.created_at desc, d.id desc limit ${limit} offset ${(page - 1) * limit}`, args)).rows;
  return c.json({ data: rows.map(({ total, ...r }) => r), total: rows[0]?.total ?? 0, page, per_page: limit });
});

adminPushTemplateRoutes.get("/admin/push-deliveries/stats", ...guard("push_template list"), async (c) => {
  const db = c.get("db");
  const days = num(c.req.query("days"), 7, 1, 90);
  const win = "d.created_at > now() - make_interval(days => $1::int) and not d.is_test";
  const totals = (await db.query(`select d.status, count(*)::int as n from app.push_deliveries d where ${win} group by d.status`, [days])).rows;
  const byTemplate = (await db.query(
    `select d.template_key, count(*)::int as total, (count(*) filter (where d.status='sent'))::int as sent, (count(*) filter (where d.status='failed'))::int as failed, (count(*) filter (where d.status='skipped'))::int as skipped
       from app.push_deliveries d where ${win} group by d.template_key order by total desc limit 25`, [days])).rows;
  const byDay = (await db.query(
    `select to_char(date_trunc('day', d.created_at), 'YYYY-MM-DD') as day, (count(*) filter (where d.status='sent'))::int as sent, (count(*) filter (where d.status='failed'))::int as failed, (count(*) filter (where d.status='skipped'))::int as skipped
       from app.push_deliveries d where ${win} group by 1 order by 1`, [days])).rows;
  const reasons = (await db.query(
    `select d.reason, count(*)::int as n from app.push_deliveries d where ${win} and d.status in ('failed','skipped') and d.reason is not null group by d.reason order by n desc limit 10`, [days])).rows;
  const t: Record<string, number> = { sent: 0, failed: 0, skipped: 0, queued: 0 };
  for (const r of totals) t[String(r.status)] = r.n;
  return c.json({
    days, totals: t, by_template: byTemplate, by_day: byDay, reasons,
    note: "Sent means OneSignal accepted the notification. It does not prove the phone showed it. Test sends are not counted.",
  });
});
