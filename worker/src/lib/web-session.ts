import type { Client } from "pg";
import type { Context } from "hono";
import type { AppEnv, AuthUser } from "../env";
import { createToken, parseBearer, sha256Hex } from "../auth/tokens";
import { USER_COLUMNS } from "../auth/middleware";

/**
 * Dedicated web-session architecture (Phase 1).
 *
 * Storage: web sessions are normal rows in app.api_tokens with name = 'web_session'
 * and a 30-day expires_at, created through the existing createToken() helper.
 * Validation reuses the mobile rules (hash match, expiry, deleted_at, banned) plus
 * the name check, so a mobile Bearer token can never authenticate as a web session
 * and revocation paths (logout, password change/reset, admin reset, self-delete,
 * ban) automatically invalidate web sessions because they operate on the same table.
 *
 * Transport: the token secret travels only in an HttpOnly cookie. It is never
 * serialized into JSON, HTML or JavaScript, and never stored in localStorage.
 *
 * CSRF: two layers.
 * 1. Pre-authentication (login/register are state-changing): GET /api/web/csrf
 *    issues a random token in a readable `drop_csrf` cookie AND in the JSON body
 *    (double submit). POST /api/web/register and POST /api/web/login require the
 *    matching X-CSRF-Token header, plus strict Origin checking and
 *    Sec-Fetch-Site enforcement (see originAllowed below). This defeats login CSRF
 *    and cross-site registration without needing an authenticated session first.
 * 2. Post-authentication (/mode, /logout): the CSRF token is
 *    HMAC(SESSION_SECRET, web_token_id), bound to the session, still sent as
 *    X-CSRF-Token and compared in constant time.
 */

export const WEB_SESSION_NAME = "web_session";
export const SESSION_COOKIE = "drop_session";
export const CSRF_COOKIE = "drop_csrf";
export const CSRF_HEADER = "x-csrf-token";
const SESSION_DAYS = 30;
const REFRESH_THRESHOLD_DAYS = 7;

const te = new TextEncoder();

/** Constant-time string comparison (length leak is acceptable; content is not). */
export function safeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let d = 0;
  for (let i = 0; i < a.length; i++) d |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return d === 0;
}

function randomToken(bytes = 32): string {
  const b = crypto.getRandomValues(new Uint8Array(bytes));
  return [...b].map((x) => x.toString(16).padStart(2, "0")).join("");
}

async function hmacHex(secret: string, message: string): Promise<string> {
  const key = await crypto.subtle.importKey("raw", te.encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const sig = await crypto.subtle.sign("HMAC", key, te.encode(message));
  return [...new Uint8Array(sig)].map((x) => x.toString(16).padStart(2, "0")).join("");
}

/**
 * Strict Origin validation for state-changing web routes. The Origin must be
 * present and exactly equal to the request's own origin (scheme + host + port).
 * Missing Origin on a POST is rejected: same-origin fetch() always sends it.
 */
export function originAllowed(c: Context<AppEnv>): boolean {
  const origin = c.req.header("origin");
  if (!origin) return false;
  try {
    return new URL(origin).origin === new URL(c.req.url).origin;
  } catch {
    return false;
  }
}

/**
 * Fetch Metadata check (defense in depth alongside Origin). When the browser
 * sends Sec-Fetch-Site, a same-origin state-changing request must say so.
 * Requests without the header (older browsers, curl) fall through to the
 * Origin check above rather than failing closed here.
 */
export function fetchMetadataAllowed(c: Context<AppEnv>): boolean {
  const site = c.req.header("sec-fetch-site");
  if (!site) return true;
  return site === "same-origin";
}

/** HMAC-bound CSRF token for an authenticated web session. */
export async function sessionCsrf(secret: string, tokenId: number): Promise<string> {
  return hmacHex(secret, `web-csrf:${tokenId}`);
}

/** Parses the session cookie into { id, secret }, or null when absent/malformed. */
export function parseSessionCookie(c: Context<AppEnv>): { id: number; secret: string } | null {
  const header = c.req.header("cookie") ?? "";
  const m = /(?:^|;\s*)drop_session=([^;]+)/.exec(header);
  if (!m) return null;
  try {
    return parseBearer(`Bearer ${decodeURIComponent(m[1])}`);
  } catch {
    return null;
  }
}

/** Validates a parsed session cookie against the database. Returns the token row id + user + expiry. */
export async function validateSession(
  db: Client,
  parsed: { id: number; secret: string },
): Promise<{ tokenId: number; user: AuthUser; expiresAt: Date | null } | null> {
  const found = await db.query(
    `select t.id as token_id, t.expires_at, t.last_used_at, ${USER_COLUMNS}
     from app.api_tokens t
     join app.users u on u.id = t.user_id
     where t.id = $1 and t.token_hash = $2 and t.name = $3 and u.deleted_at is null`,
    [parsed.id, await sha256Hex(parsed.secret), WEB_SESSION_NAME],
  );
  const row = found.rows[0];
  if (!row) return null;
  if (row.expires_at && new Date(row.expires_at) < new Date()) return null;
  if (row.status === "banned") return null;
  const { token_id, expires_at, last_used_at, ...user } = row;
  void last_used_at;
  return {
    tokenId: token_id as number,
    user: user as AuthUser,
    expiresAt: expires_at ? new Date(expires_at) : null,
  };
}

/**
 * Sliding refresh: when fewer than REFRESH_THRESHOLD_DAYS remain, extend the
 * session back to a full SESSION_DAYS. Returns the new expiry when extended.
 */
export async function maybeRefresh(db: Client, tokenId: number, expiresAt: unknown): Promise<Date | null> {
  const exp = expiresAt ? new Date(expiresAt as string | Date) : null;
  if (!exp || Number.isNaN(exp.getTime())) return null;
  if (exp.getTime() - Date.now() > REFRESH_THRESHOLD_DAYS * 86400_000) return null;
  const r = await db.query("update app.api_tokens set expires_at = now() + ($2 || ' days')::interval where id = $1 returning expires_at", [
    tokenId,
    String(SESSION_DAYS),
  ]);
  return r.rows[0]?.expires_at ? new Date(r.rows[0].expires_at) : null;
}

/** Creates a web session row and returns the cookie value + token id + expiry. */
export async function createWebSession(
  db: Client,
  userId: number,
): Promise<{ cookieValue: string; tokenId: number; expires: Date }> {
  const token = await createToken(db, userId, WEB_SESSION_NAME);
  const id = Number(token.split("|")[0]);
  await db.query("update app.api_tokens set expires_at = now() + ($2 || ' days')::interval where id = $1", [id, String(SESSION_DAYS)]);
  const row = (await db.query("select expires_at from app.api_tokens where id = $1", [id])).rows[0];
  return { cookieValue: token, tokenId: id, expires: new Date(row.expires_at) };
}

/** Deletes one web session row (logout). */
export async function revokeWebSession(db: Client, tokenId: number): Promise<void> {
  await db.query("delete from app.api_tokens where id = $1 and name = $2", [tokenId, WEB_SESSION_NAME]);
}

const cookieAttrs = (expires: Date) =>
  `Path=/; HttpOnly; Secure; SameSite=Lax; Expires=${expires.toUTCString()}`;

export function sessionCookieHeader(value: string, expires: Date): string {
  return `${SESSION_COOKIE}=${encodeURIComponent(value)}; ${cookieAttrs(expires)}`;
}

export function clearSessionCookieHeader(): string {
  return `${SESSION_COOKIE}=; Path=/; HttpOnly; Secure; SameSite=Lax; Expires=Thu, 01 Jan 1970 00:00:00 GMT`;
}

/** Readable (non-HttpOnly) CSRF cookie for the pre-auth double-submit token. */
export function csrfCookieHeader(token: string): string {
  const exp = new Date(Date.now() + 30 * 60_000).toUTCString();
  return `${CSRF_COOKIE}=${encodeURIComponent(token)}; Path=/; Secure; SameSite=Lax; Expires=${exp}`;
}

export function newPreAuthCsrf(): string {
  return randomToken(32);
}
