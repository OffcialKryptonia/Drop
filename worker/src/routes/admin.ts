import { Hono, type Context, type Next } from "hono";
import { z } from "zod";
import type { AppEnv } from "../env";
import { withDb } from "../db";
import { requireAuth } from "../auth/middleware";
import { hashPassword } from "../auth/password";
import { createToken } from "../auth/tokens";
import { decryptValue, encryptValue } from "../lib/crypto";
import { GATEWAY_FIELDS } from "../lib/gateways";
import { MESSAGES, readBody, validationFailed } from "../lib/legacy";

export const adminRoutes = new Hono<AppEnv>();

/** Constant-time string compare. */
function safeEqual(a: string, b: string): boolean {
  const enc = new TextEncoder();
  const x = enc.encode(a), y = enc.encode(b);
  let diff = x.length ^ y.length;
  for (let i = 0; i < Math.max(x.length, y.length); i++) diff |= (x[i] ?? 0) ^ (y[i] ?? 0);
  return diff === 0;
}

/**
 * Creates the FIRST admin. Works only while (a) the Worker secret ADMIN_BOOTSTRAP_TOKEN is set and
 * (b) no admin exists yet. After that it answers 404 forever.
 */
const bootstrapSchema = z.object({
  token: z.string().min(1),
  first_name: z.string().trim().min(1).max(100),
  last_name: z.string().trim().min(1).max(100),
  email: z.string().trim().toLowerCase().email(),
  username: z.string().trim().min(3).max(100),
  password: z.string().min(10).max(72),
});

adminRoutes.post("/admin/bootstrap", withDb, async (c) => {
  const expected = c.env.ADMIN_BOOTSTRAP_TOKEN;
  const db = c.get("db");
  const exists = await db.query("select 1 from app.users where user_type = 'admin' and deleted_at is null limit 1");
  if (!expected || exists.rows.length) return c.json({ message: "Not found", status: 404 }, 404);

  const parsed = bootstrapSchema.safeParse(await readBody(c));
  if (!parsed.success) {
    const errors: Record<string, string[]> = {};
    for (const i of parsed.error.issues) (errors[String(i.path[0])] ??= []).push(i.message);
    return validationFailed(c, errors);
  }
  const d = parsed.data;
  if (!safeEqual(d.token, expected)) return c.json({ message: "Not found", status: 404 }, 404);

  const ins = await db.query(
    `insert into app.users (first_name, last_name, display_name, email, username, password_hash, login_type, user_type, status)
     values ($1,$2,$3,$4,$5,$6,'app','admin','active') returning id`,
    [d.first_name, d.last_name, `${d.first_name} ${d.last_name}`, d.email, d.username, await hashPassword(d.password)],
  );
  await db.query("insert into app.admin_audit (admin_id, action) values ($1, 'bootstrap_admin')", [ins.rows[0].id]);
  return c.json({ message: "Admin created. You can sign in now.", api_token: await createToken(db, ins.rows[0].id) });
});

// Everything below is admin-only.
const adminOnly = [
  withDb,
  requireAuth,
  async (c: Context<AppEnv>, next: Next) => {
    if (c.get("user").user_type !== "admin") return c.json({ message: "Forbidden" }, 403);
    await next();
  },
] as const;

adminRoutes.get("/admin/payment-gateways", ...adminOnly, async (c) => {
  const db = c.get("db");
  const gws = await db.query("select type, title, status, is_test, sort_order from app.payment_gateways order by sort_order, id");
  const creds = await db.query("select gateway_type, mode, field, value_enc, is_secret, last4, updated_at from app.gateway_credentials");
  const data = [];
  for (const g of gws.rows) {
    const fields = [];
    for (const f of GATEWAY_FIELDS[g.type] ?? []) {
      const entry: Record<string, unknown> = { key: f.key, label: f.label, secret: f.secret, hint: f.hint ?? null, test: null, live: null };
      for (const mode of ["test", "live"] as const) {
        const row = creds.rows.find((r) => r.gateway_type === g.type && r.mode === mode && r.field === f.key);
        if (!row) continue;
        // Secrets are never sent back: only a masked tail. Plain fields (IDs, public keys) are shown.
        entry[mode] = f.secret
          ? { set: true, masked: `••••${row.last4 ?? ""}`, updated_at: row.updated_at }
          : { set: true, value: await decryptValue(row.value_enc, c.env.SETTINGS_ENCRYPTION_KEY).catch(() => ""), updated_at: row.updated_at };
      }
      fields.push(entry);
    }
    const ready = (mode: string) =>
      (GATEWAY_FIELDS[g.type] ?? []).every((f) => creds.rows.some((r) => r.gateway_type === g.type && r.mode === mode && r.field === f.key));
    data.push({ type: g.type, title: g.title, status: g.status, is_test: g.is_test, fields, ready_test: ready("test"), ready_live: ready("live") });
  }
  return c.json({ data, encryption_configured: (c.env.SETTINGS_ENCRYPTION_KEY ?? "").length >= 32 });
});

const updateSchema = z.object({
  status: z.boolean().optional(),
  is_test: z.boolean().optional(),
  // { test: { api_token: "..." }, live: {...} }. Empty string = leave unchanged, null = delete.
  credentials: z
    .object({
      test: z.record(z.string(), z.string().max(500).nullable()).optional(),
      live: z.record(z.string(), z.string().max(500).nullable()).optional(),
    })
    .optional(),
});

adminRoutes.put("/admin/payment-gateways/:type", ...adminOnly, async (c) => {
  const type = c.req.param("type");
  const spec = GATEWAY_FIELDS[type];
  if (!spec) return c.json({ message: "Unknown payment method" }, 404);
  const parsed = updateSchema.safeParse(await readBody(c));
  if (!parsed.success) return validationFailed(c, { body: ["Invalid request."] });
  const { status, is_test, credentials } = parsed.data;
  const db = c.get("db");
  const admin = c.get("user");
  const changed: string[] = [];

  // Refuse to switch a method on without a complete credential set for the mode it will run in.
  if (status === true || is_test !== undefined) {
    const cur = (await db.query("select status, is_test from app.payment_gateways where type = $1", [type])).rows[0];
    const willBeOn = status ?? cur.status;
    const mode = (is_test ?? cur.is_test) ? "test" : "live";
    if (willBeOn && spec.length) {
      const have = (await db.query("select field from app.gateway_credentials where gateway_type = $1 and mode = $2", [type, mode])).rows.map((r) => r.field);
      const incoming = Object.entries(credentials?.[mode] ?? {}).filter(([, v]) => v).map(([k]) => k);
      const missing = spec.filter((f) => !have.includes(f.key) && !incoming.includes(f.key)).map((f) => f.label);
      if (missing.length) {
        return c.json({ message: `Add ${mode} credentials first: ${missing.join(", ")}.`, status: 422 }, 422);
      }
    }
  }

  try {
    await db.query("begin");
    for (const [mode, fields] of Object.entries(credentials ?? {})) {
      for (const [key, value] of Object.entries(fields ?? {})) {
        const def = spec.find((f) => f.key === key);
        if (!def) continue;
        if (value === null) {
          await db.query("delete from app.gateway_credentials where gateway_type=$1 and mode=$2 and field=$3", [type, mode, key]);
          changed.push(`${mode}.${key}:cleared`);
        } else if (value.trim() !== "") {
          const v = value.trim();
          await db.query(
            `insert into app.gateway_credentials (gateway_type, mode, field, value_enc, is_secret, last4, updated_by)
             values ($1,$2,$3,$4,$5,$6,$7)
             on conflict (gateway_type, mode, field) do update
               set value_enc = excluded.value_enc, last4 = excluded.last4, updated_by = excluded.updated_by, updated_at = now()`,
            [type, mode, key, await encryptValue(v, c.env.SETTINGS_ENCRYPTION_KEY), def.secret, def.secret ? v.slice(-4) : null, admin.id],
          );
          changed.push(`${mode}.${key}:set`);
        }
      }
    }
    if (status !== undefined || is_test !== undefined) {
      await db.query(
        "update app.payment_gateways set status = coalesce($2, status), is_test = coalesce($3, is_test) where type = $1",
        [type, status ?? null, is_test ?? null],
      );
      if (status !== undefined) changed.push(`status:${status}`);
      if (is_test !== undefined) changed.push(`mode:${is_test ? "test" : "live"}`);
    }
    await db.query("insert into app.admin_audit (admin_id, action, target, detail) values ($1,'gateway_update',$2,$3)", [admin.id, type, JSON.stringify({ changed })]);
    await db.query("commit");
  } catch (err) {
    await db.query("rollback").catch(() => undefined);
    if (err instanceof Error && err.message.includes("SETTINGS_ENCRYPTION_KEY")) {
      return c.json({ message: "Encryption key is not configured on the server yet.", status: 503 }, 503);
    }
    throw err;
  }
  return c.json({ message: "Saved", changed });
});
