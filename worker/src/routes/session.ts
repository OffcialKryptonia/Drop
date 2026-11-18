import { Hono, type Context } from "hono";
import { z } from "zod";
import type { AppEnv } from "../env";
import { UNIQUE_VIOLATION, withDb } from "../db";
import { USER_COLUMNS } from "../auth/middleware";
import { hashPassword, verifyPassword } from "../auth/password";
import { MESSAGES, readBody, validationFailed } from "../lib/legacy";
import { nationalNumber } from "../lib/phone";
import { serializeUser } from "../serializers/user";
import {
  CSRF_COOKIE,
  CSRF_HEADER,
  clearSessionCookieHeader,
  createWebSession,
  csrfCookieHeader,
  fetchMetadataAllowed,
  maybeRefresh,
  newPreAuthCsrf,
  originAllowed,
  parseSessionCookie,
  revokeWebSession,
  safeEqual,
  sessionCookieHeader,
  sessionCsrf,
  validateSession,
} from "../lib/web-session";
import { driverModeBlock } from "../lib/roles";

/**
 * Browser session endpoints (Phase 1: shared authentication only).
 *
 * These reuse the exact mobile account logic (same tables, same validation,
 * same password hashing) but transport the credential in an HttpOnly cookie
 * instead of returning an api_token to JavaScript. The mobile contracts in
 * routes/auth.ts are untouched.
 *
 * Anti-abuse: no in-Worker counters exist on purpose (per-isolate memory would
 * give false confidence). Enforcement is Cloudflare WAF rate-limit rules on
 * /api/web/login and /api/web/register (documented in the Phase 1 report).
 * Failed logins still run the dummy-hash comparison from verifyPassword, so
 * unknown-account and wrong-password take the same time.
 */

export const sessionRoutes = new Hono<AppEnv>();
type C = Context<AppEnv>;

/** Pre-auth CSRF gate for login/register: Origin + Fetch Metadata + double-submit token. */
const preAuthCsrfOk = (c: C): boolean => {
  if (!originAllowed(c) || !fetchMetadataAllowed(c)) return false;
  const header = c.req.header(CSRF_HEADER) ?? "";
  const cookies = c.req.header("cookie") ?? "";
  const m = new RegExp(`(?:^|;\\s*)${CSRF_COOKIE}=([^;]+)`).exec(cookies);
  if (!m || !header) return false;
  try {
    return safeEqual(decodeURIComponent(m[1]), header);
  } catch {
    return false;
  }
};

const csrfReject = (c: C) =>
  c.json({ message: "Request could not be verified. Please reload the page and try again.", code: "csrf_invalid" }, 403);

/** Issues a pre-auth CSRF token: readable cookie + JSON body (double submit). */
sessionRoutes.get("/web/csrf", (c) => {
  const token = newPreAuthCsrf();
  c.header("Set-Cookie", csrfCookieHeader(token));
  c.header("Cache-Control", "no-store");
  return c.json({ csrf_token: token });
});

type Session = { tokenId: number; csrf: string; userId: number };

/** Validates the session cookie and the HMAC-bound CSRF header for authed mutations. */
async function authed(c: C): Promise<Session | null> {
  const secret = c.env.SESSION_SECRET;
  if (!secret || secret.length < 32) return null;
  const parsed = parseSessionCookie(c);
  if (!parsed) return null;
  const db = c.get("db");
  const s = await validateSession(db, parsed);
  if (!s) return null;
  if (!originAllowed(c) || !fetchMetadataAllowed(c)) return null;
  const header = c.req.header(CSRF_HEADER) ?? "";
  if (!header || !safeEqual(header, await sessionCsrf(secret, s.tokenId))) return null;
  return { tokenId: s.tokenId, csrf: header, userId: s.user.id as number };
}

const authedReject = (c: C) =>
  c.json({ message: "Your session is not valid. Please log in again.", code: "session_invalid" }, 401);

/** Fresh view of the signed-in user: roles, mode and driver status for routing. */
sessionRoutes.get("/web/me", withDb, async (c) => {
  const secret = c.env.SESSION_SECRET;
  if (!secret || secret.length < 32) return c.json({ message: "Web login is not configured yet.", code: "session_unconfigured" }, 503);
  const parsed = parseSessionCookie(c);
  if (!parsed) return c.json({ signed_in: false }, 200);
  const db = c.get("db");
  const s = await validateSession(db, parsed);
  if (!s) return c.json({ signed_in: false }, 200);
  const row = (await db.query(`select ${USER_COLUMNS} from app.users u where u.id = $1`, [s.user.id])).rows[0];
  if (!row) return c.json({ signed_in: false }, 200);
  const refreshed = await maybeRefresh(db, s.tokenId, s.expiresAt);
  if (refreshed) {
    // Re-serialize the cookie so the browser keeps the new expiry.
    c.header("Set-Cookie", sessionCookieHeader(`${parsed.id}|${parsed.secret}`, refreshed));
  }
  c.header("Cache-Control", "no-store");
  return c.json({ signed_in: true, data: serializeUser(row), csrf_token: await sessionCsrf(secret, s.tokenId) });
});

// ---------------------------------------------------------------- login
const loginSchema = z.object({
  identifier: z.string().trim().max(255).optional(),
  email: z.string().trim().max(255).optional(),
  password: z.string().min(1, "The password field is required.").max(200),
});

function loginIssues(err: z.ZodError): Record<string, string[]> {
  const out: Record<string, string[]> = {};
  for (const i of err.issues) (out[String(i.path[0] ?? "body")] ??= []).push(i.message);
  return out;
}

sessionRoutes.post("/web/login", withDb, async (c) => {
  if (!c.env.SESSION_SECRET || c.env.SESSION_SECRET.length < 32)
    return c.json({ message: "Web login is not configured yet.", code: "session_unconfigured" }, 503);
  if (!preAuthCsrfOk(c)) return csrfReject(c);
  const parsed = loginSchema.safeParse(await readBody(c));
  if (!parsed.success) return validationFailed(c, loginIssues(parsed.error));
  const identifier = (parsed.data.identifier || parsed.data.email || "").trim();
  if (!identifier) return validationFailed(c, { identifier: ["Enter your phone number or username."] });
  const db = c.get("db");

  let where: string;
  let arg: string;
  if (identifier.includes("@")) {
    where = "u.email = $1";
    arg = identifier.toLowerCase();
  } else if (/^[+\d][\d\s()-]{6,}$/.test(identifier)) {
    const digits = identifier.replace(/\D/g, "");
    const full = identifier.startsWith("+")
      ? digits
      : digits.startsWith("234") && digits.length >= 12
        ? digits
        : "234" + digits.replace(/^0+/, "");
    where = "app.phone_digits(u.country_code, u.contact_number) = $1";
    arg = full;
  } else {
    where = "u.username = $1";
    arg = identifier;
  }

  const found = await db.query(
    `select u.password_hash, ${USER_COLUMNS} from app.users u where ${where} and u.deleted_at is null limit 1`,
    [arg],
  );
  const row = found.rows[0];
  const ok = await verifyPassword(db, parsed.data.password, row?.password_hash ?? null);
  if (!row || !ok) return c.json({ status: false, message: MESSAGES.authFailed }, 200);
  if (row.status === "banned") return c.json({ status: false, message: MESSAGES.accountBanned }, 200);

  // Same mode resolution as mobile login: rider default; approved drivers keep driver mode when still online.
  const roles = (row.roles ?? []) as string[];
  const mode = row.is_online && row.active_mode === "driver" && roles.includes("driver") ? "driver" : "rider";
  await db.query("update app.users set last_actived_at = now(), active_mode = $2 where id = $1", [row.id, mode]);
  const fresh = (await db.query(`select ${USER_COLUMNS} from app.users u where u.id = $1`, [row.id])).rows[0];

  const sess = await createWebSession(db, row.id);
  const secret = c.env.SESSION_SECRET as string;
  c.header("Set-Cookie", sessionCookieHeader(sess.cookieValue, sess.expires));
  c.header("Cache-Control", "no-store");
  return c.json({ status: true, data: serializeUser(fresh), csrf_token: await sessionCsrf(secret, sess.tokenId) });
});

// ---------------------------------------------------------------- register
const opt = (max = 255) =>
  z.preprocess((v) => (v === "" || v === undefined ? null : v), z.string().max(max).nullable());
const registerSchema = z.object({
  first_name: z.string().trim().min(1, "The first name field is required.").max(100),
  last_name: z.string().trim().min(1, "The last name field is required.").max(100),
  email: z.preprocess(
    (v) => (v === "" || v == null ? null : v),
    z.string().trim().toLowerCase().email("The email must be a valid email address.").max(255).nullable(),
  ),
  username: z.preprocess(
    (v) => (v === "" || v == null ? null : v),
    z.string().trim().min(3, "The username must be at least 3 characters.").max(100).nullable(),
  ),
  password: z.string().min(8, "The password must be at least 8 characters.").max(72, "The password must not be greater than 72 characters."),
  user_type: z.enum(["rider", "driver"]).default("rider"),
  contact_number: opt(30),
  country_code: opt(10),
  gender: z.preprocess((v) => (v === "" ? null : v), z.enum(["male", "female", "other"]).nullable().optional()),
});

sessionRoutes.post("/web/register", withDb, async (c) => {
  if (!c.env.SESSION_SECRET || c.env.SESSION_SECRET.length < 32)
    return c.json({ message: "Web login is not configured yet.", code: "session_unconfigured" }, 503);
  if (!preAuthCsrfOk(c)) return csrfReject(c);
  const parsed = registerSchema.safeParse(await readBody(c));
  if (!parsed.success) return validationFailed(c, loginIssues(parsed.error));
  const d = parsed.data;
  const db = c.get("db");
  if (!d.email && !d.contact_number) return validationFailed(c, { contact_number: ["Enter your phone number."] });
  if (d.contact_number) {
    const national = nationalNumber(d.country_code ?? "+234", d.contact_number);
    if (national.length < 6 || national.length > 13) return validationFailed(c, { contact_number: ["Enter a valid phone number."] });
    d.contact_number = national;
    d.country_code = (d.country_code ?? "+234").replace(/[^\d+]/g, "") || "+234";
    if (!d.country_code.startsWith("+")) d.country_code = "+" + d.country_code;
  }
  const baseName = (d.username ?? `${d.first_name}${d.last_name}`).toLowerCase().replace(/[^a-z0-9_.]/g, "").slice(0, 20) || "user";
  const usernameGiven = d.username != null;
  d.username = usernameGiven ? d.username : `${baseName}${Math.floor(1000 + Math.random() * 9000)}`;

  const status = d.user_type === "driver" ? "pending" : "active";
  const hash = await hashPassword(db, d.password);
  const referral = crypto.randomUUID().replace(/-/g, "").slice(0, 8).toUpperCase();

  try {
    await db.query("begin");
    const ins = await db.query(
      `insert into app.users (first_name, last_name, display_name, email, username, password_hash,
        user_type, status, country_code, contact_number, gender, timezone, referral_code, roles, active_mode, last_actived_at)
       values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,'UTC',$12,$13,$14, now())
       returning id`,
      [
        d.first_name, d.last_name, `${d.first_name} ${d.last_name}`.trim(), d.email, d.username, hash,
        d.user_type, status, d.country_code, d.contact_number, d.gender ?? null, referral,
        d.user_type === "driver" ? ["rider", "driver"] : ["rider"],
        "rider",
      ],
    );
    const id = ins.rows[0].id as number;
    if (d.user_type === "driver") {
      await db.query("insert into app.driver_profiles (user_id, status) values ($1, 'draft')", [id]);
    }
    const sess = await createWebSession(db, id);
    const user = await db.query(`select ${USER_COLUMNS} from app.users u where u.id = $1`, [id]);
    await db.query("commit");
    c.header("Set-Cookie", sessionCookieHeader(sess.cookieValue, sess.expires));
    c.header("Cache-Control", "no-store");
    const secret = c.env.SESSION_SECRET as string;
    return c.json({
      message: d.user_type === "driver" ? MESSAGES.driverSaved : MESSAGES.riderSaved,
      status: true,
      data: serializeUser(user.rows[0]),
      csrf_token: await sessionCsrf(secret, sess.tokenId),
    });
  } catch (err) {
    await db.query("rollback").catch(() => undefined);
    const e = err as { code?: string; constraint?: string };
    if (e.code === UNIQUE_VIOLATION) {
      if (e.constraint?.includes("phone")) return validationFailed(c, { contact_number: ["This phone number already has an account. Please log in instead."] });
      if (e.constraint?.includes("username")) {
        return validationFailed(c, { username: [usernameGiven ? "The username has already been taken." : "Please try again."] });
      }
      return validationFailed(c, { email: ["The email has already been taken."] });
    }
    throw err;
  }
});

// ---------------------------------------------------------------- mode + logout (authed, CSRF-bound)
sessionRoutes.post("/web/mode", withDb, async (c) => {
  const s = await authed(c);
  if (!s) return authedReject(c);
  const p = z.object({ mode: z.enum(["rider", "driver"]) }).safeParse(await readBody(c));
  if (!p.success) return validationFailed(c, { mode: ["The mode must be rider or driver."] });
  const db = c.get("db");
  const me = (await db.query(`select ${USER_COLUMNS} from app.users u where u.id = $1`, [s.userId])).rows[0];
  if (!me) return authedReject(c);
  if (me.user_type === "admin" || me.user_type === "fleet") return c.json({ status: false, code: "not_available", message: "Mode switching is for passengers and drivers." }, 403);
  if (p.data.mode === "driver") {
    const block = await driverModeBlock(db, me.id);
    if (block) return c.json({ status: false, ...block }, 403);
  }
  const open = (await db.query(
    `select (rider_id = $1) as passenger from app.ride_requests where (rider_id = $1 or driver_id = $1) and status in ('searching', 'accepted', 'arrived', 'in_progress') limit 1`,
    [me.id],
  )).rows[0];
  if (open) {
    return c.json({
      status: false, code: "active_trip",
      message: p.data.mode === "driver" && open.passenger
        ? "You have a ride request open. Cancel it or wait for it to finish, then switch to Driver mode."
        : "Finish your current trip before switching.",
    }, 409);
  }
  await db.query(
    `update app.users set active_mode = $2, is_online = case when $2 = 'rider' then false else is_online end,
     is_available = case when $2 = 'rider' then false else is_available end where id = $1`,
    [me.id, p.data.mode],
  );
  const row = (await db.query(`select ${USER_COLUMNS} from app.users u where u.id = $1`, [me.id])).rows[0];
  c.header("Cache-Control", "no-store");
  return c.json({ status: true, data: serializeUser(row) });
});

sessionRoutes.post("/web/logout", withDb, async (c) => {
  const s = await authed(c);
  if (!s) return authedReject(c);
  const db = c.get("db");
  await revokeWebSession(db, s.tokenId);
  c.header("Set-Cookie", clearSessionCookieHeader());
  c.header("Cache-Control", "no-store");
  return c.json({ message: MESSAGES.logout });
});
