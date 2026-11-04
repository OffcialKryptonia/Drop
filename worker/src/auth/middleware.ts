import type { MiddlewareHandler } from "hono";
import type { AppEnv, AuthUser } from "../env";
import { unauthenticated } from "../lib/legacy";
import { parseBearer, sha256Hex } from "./tokens";

/** Every user column the API may expose. Never includes password_hash, otp_hash or the raw geography. */
export const USER_COLUMNS = `
  u.id, u.first_name, u.last_name, u.display_name, u.email, u.username, u.apple_user_identifier,
  u.uid, u.login_type, u.user_type, u.status, u.country_code, u.contact_number, u.gender, u.address,
  u.timezone, u.email_verified_at, u.otp_verify_at, u.player_id, u.fcm_token, u.app_version,
  u.service_id, u.fleet_id, u.is_online, u.is_available, u.is_verified_driver, u.latitude, u.longitude,
  u.current_heading, u.last_location_update_at, u.last_actived_at, u.last_notification_seen,
  u.total_coins, u.referral_code, u.partner_referral_code, u.created_at, u.updated_at`;

/**
 * Requires "Authorization: Bearer <id>|<secret>". Rejects missing, malformed, unknown,
 * expired and deleted-user tokens, and banned users, all with the legacy 401 body (the
 * apps sign the user out on a 401).
 */
export const requireAuth: MiddlewareHandler<AppEnv> = async (c, next) => {
  const bearer = parseBearer(c.req.header("authorization"));
  if (!bearer) return unauthenticated(c);

  const db = c.get("db");
  const found = await db.query(
    `select t.id as token_id, t.expires_at, t.last_used_at, ${USER_COLUMNS}
       from app.api_tokens t
       join app.users u on u.id = t.user_id
      where t.id = $1 and t.token_hash = $2 and u.deleted_at is null`,
    [bearer.id, await sha256Hex(bearer.secret)],
  );
  const row = found.rows[0];
  if (!row) return unauthenticated(c);
  if (row.expires_at && new Date(row.expires_at) < new Date()) return unauthenticated(c);
  if (row.status === "banned") return unauthenticated(c);

  // Record usage at most every 5 minutes, so reads do not turn into writes.
  if (!row.last_used_at || Date.now() - new Date(row.last_used_at).getTime() > 5 * 60_000) {
    await db.query("update app.api_tokens set last_used_at = now() where id = $1", [row.token_id]);
  }

  const { token_id, expires_at, last_used_at, ...user } = row;
  c.set("user", user as AuthUser);
  c.set("tokenId", token_id as number);
  await next();
};
