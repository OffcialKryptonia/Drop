import { Hono } from "hono";
import type { AppEnv } from "../env";
import { guard } from "../lib/permissions";
import { validationFailed } from "../lib/legacy";
import { parsePeriod } from "../lib/analytics";

/**
 * The Audit Log screen. Read only: there is no route that edits or deletes an audit row, and the database refuses such changes too
 * (see the append-only trigger in the Phase 7 migration). Values whose names suggest a secret are masked on the way out as a second line of defence.
 */
export const adminAuditLogRoutes = new Hono<AppEnv>();
type Row = Record<string, unknown>;
const SECRET = /pass(word)?|secret|token|api[_-]?key|rest[_-]?key|otp|pin\b|authorization|credential|private/i;

export function redact(v: unknown, depth = 0): unknown {
  if (depth > 6) return "…";
  if (Array.isArray(v)) return v.slice(0, 50).map((x) => redact(x, depth + 1));
  if (v && typeof v === "object") return Object.fromEntries(Object.entries(v as Row).slice(0, 80).map(([k, x]) => [k, SECRET.test(k) ? "••••" : redact(x, depth + 1)]));
  return typeof v === "string" && v.length > 500 ? v.slice(0, 500) + "…" : v;
}
const NAME = (a: string) => `coalesce(nullif(btrim(${a}.display_name), ''), nullif(btrim(concat_ws(' ', ${a}.first_name, ${a}.last_name)), ''), ${a}.username)`;

adminAuditLogRoutes.get("/admin/audit-logs", ...guard("audit_log list"), async (c) => {
  const db = c.get("db");
  const q = c.req.query();
  const p = parsePeriod({ from: q.from, to: q.to, tz: q.tz });
  if ("error" in p) return validationFailed(c, { from: [p.error] });
  const b = (await db.query("select (($1::date)::timestamp at time zone $3) as s, ((($2::date) + 1)::timestamp at time zone $3) as e", [p.from, p.to, p.tz])).rows[0];
  const where = ["a.created_at >= $1", "a.created_at < $2"];
  const args: unknown[] = [b.s, b.e];
  const add = (sql: string, v: unknown) => { args.push(v); where.push(sql.replace("?", `$${args.length}`)); };
  if (q.admin_id && /^\d{1,15}$/.test(q.admin_id)) add("a.admin_id = ?", Number(q.admin_id));
  if (q.action) add("a.action = ?", q.action.slice(0, 80));
  if (q.target) add("a.target = ?", q.target.slice(0, 120));
  const needle = (q.q ?? "").trim().slice(0, 80);
  if (needle) add("(a.action ilike '%' || ?::text || '%' or a.target ilike '%' || ?::text || '%' or a.detail::text ilike '%' || ?::text || '%')".replace(/\?::text/g, "$" + (args.length + 1) + "::text"), needle);
  const page = Math.max(Number(q.page) || 1, 1);
  const w = where.join(" and ");
  const total = Number((await db.query(`select count(*)::int n from app.admin_audit a where ${w}`, args)).rows[0].n);
  const rows = (await db.query(
    `select a.id, a.created_at, a.action, a.target, a.detail, a.admin_id, ${NAME("u")} as admin_name
       from app.admin_audit a left join app.users u on u.id = a.admin_id where ${w} order by a.id desc limit 50 offset $${args.length + 1}`, [...args, (page - 1) * 50])).rows;
  return c.json({
    status: true, period: { from: p.from, to: p.to, timezone: p.tz },
    data: rows.map((r) => ({ id: Number(r.id), at: new Date(r.created_at as string).toISOString(), action: r.action, target: r.target, detail: redact(r.detail),
      admin: r.admin_id ? { id: Number(r.admin_id), name: r.admin_name } : null })),
    pagination: { page, total_pages: Math.max(Math.ceil(total / 50), 1), total },
    protected: "Audit rows cannot be edited or deleted.",
  });
});

adminAuditLogRoutes.get("/admin/audit-logs/filters", ...guard("audit_log list"), async (c) => {
  const db = c.get("db");
  const actions = (await db.query("select action, count(*)::int n from app.admin_audit group by 1 order by 1 limit 300")).rows;
  const admins = (await db.query(`select distinct u.id, ${NAME("u")} as name from app.admin_audit a join app.users u on u.id = a.admin_id order by name limit 200`)).rows;
  return c.json({ status: true, actions: actions.map((r) => ({ action: r.action, count: Number(r.n) })), admins: admins.map((r) => ({ id: Number(r.id), name: r.name })) });
});
