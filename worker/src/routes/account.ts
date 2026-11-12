import { Hono } from "hono";
import type { AppEnv } from "../env";
import { withDb } from "../db";
import { requireAuth } from "../auth/middleware";
import { hashPassword, verifyPassword } from "../auth/password";
import { readBody, validationFailed } from "../lib/legacy";

export const accountRoutes = new Hono<AppEnv>();
const OPEN = ["searching", "accepted", "arrived", "in_progress"];

/** Change password while signed in. Other devices are signed out; this one stays. */
accountRoutes.post("/change-password", withDb, requireAuth, async (c) => {
  const db = c.get("db");
  const me = c.get("user");
  const b = await readBody(c);
  const oldPw = String(b.old_password ?? "");
  const newPw = String(b.new_password ?? "");
  if (newPw.length < 8 || newPw.length > 72) return validationFailed(c, { new_password: ["The new password must be 8 to 72 characters."] });
  const row = (await db.query("select password_hash from app.users where id = $1", [me.id])).rows[0];
  if (!(await verifyPassword(db, oldPw, row?.password_hash ?? null))) return validationFailed(c, { old_password: ["Your current password is not correct."] });
  const hash = await hashPassword(db, newPw);
  await db.query("update app.users set password_hash = $2 where id = $1", [me.id, hash]);
  // Sign out every other device; this one keeps working.
  await db.query("delete from app.api_tokens where user_id = $1 and id <> $2", [me.id, c.get("tokenId")]);
  return c.json({ status: true, message: "Password changed" });
});

/** Account deletion (an app-store requirement). Personal details are removed; wallet history stays for the books. */
accountRoutes.post("/delete-user-account", withDb, requireAuth, async (c) => {
  const db = c.get("db");
  const me = c.get("user");
  if (me.user_type !== "rider" && me.user_type !== "driver") return c.json({ message: "Forbidden" }, 403);
  const open = (await db.query("select 1 from app.ride_requests where (rider_id = $1 or driver_id = $1) and status = any($2) limit 1", [me.id, OPEN])).rowCount;
  if (open) return c.json({ status: false, message: "Finish or cancel your current ride before deleting your account." }, 409);
  const money = (await db.query("select 1 from app.wallets where user_id = $1 and balance <> 0 limit 1", [me.id])).rowCount;
  if (money) return c.json({ status: false, message: "Your wallet is not empty. Spend or move your balance first, or contact support to settle it." }, 409);
  await db.query("begin");
  try {
    await db.query(
      `update app.users set deleted_at = now(), email = null, contact_number = null, username = 'deleted_' || id,
              first_name = 'Deleted', last_name = 'user', display_name = 'Deleted user', fcm_token = null, player_id = null,
              is_online = false, is_available = false
        where id = $1`, [me.id]);
    await db.query("delete from app.api_tokens where user_id = $1", [me.id]);
    await db.query("update app.trip_shares set revoked = true where user_id = $1 and not revoked", [me.id]);
    await db.query("update app.ride_pay_links set status = 'cancelled' where user_id = $1 and status = 'pending'", [me.id]);
    await db.query("insert into app.admin_audit (admin_id, action, target) values (null, 'user_self_delete', $1)", [String(me.id)]);
    await db.query("commit");
  } catch (e) {
    await db.query("rollback").catch(() => undefined);
    throw e;
  }
  return c.json({ status: true, message: "Your account has been deleted." });
});

/** Rate the driver of a completed ride. `save-ride-rating` is the older name the earlier app used. */
const rate = async (c: any) => {
  const db = c.get("db");
  const me = c.get("user");
  const b = await readBody(c);
  const rideId = Number(b.ride_request_id ?? b.ride_id);
  const rating = Math.round(Number(b.rating));
  if (!Number.isFinite(rideId) || rideId <= 0) return validationFailed(c, { ride_request_id: ["Choose a ride to rate."] });
  if (rating === 0) return c.json({ status: true, message: "Skipped" }); // the old "skip" button
  if (!(rating >= 1 && rating <= 5)) return validationFailed(c, { rating: ["Choose 1 to 5 stars."] });
  const ride = (await db.query("select id, driver_id from app.ride_requests where id = $1 and rider_id = $2 and status = 'completed'", [rideId, me.id])).rows[0];
  if (!ride?.driver_id) return c.json({ status: false, message: "You can rate a ride once it is completed." }, 409);
  const comment = String(b.comment ?? "").trim().slice(0, 500) || null;
  await db.query(
    `insert into app.ride_ratings (ride_request_id, rider_id, driver_id, rating, comment) values ($1,$2,$3,$4,$5)
     on conflict (ride_request_id) do update set rating = excluded.rating, comment = excluded.comment`,
    [rideId, me.id, ride.driver_id, rating, comment]);
  return c.json({ status: true, message: "Thanks for your feedback" });
};
accountRoutes.post("/ride/rating", withDb, requireAuth, rate);
accountRoutes.post("/save-ride-rating", withDb, requireAuth, rate);
