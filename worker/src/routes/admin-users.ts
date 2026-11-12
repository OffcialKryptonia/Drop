import { Hono } from "hono";
import type { AppEnv } from "../env";
import { guard } from "../lib/permissions";
import { hashPassword } from "../auth/password";

export const adminUserRoutes = new Hono<AppEnv>();

/** Find a rider or driver by name, username, phone or email (for support). */
adminUserRoutes.get("/admin/users", ...guard("user_account list"), async (c) => {
  const q = (c.req.query("q") ?? "").trim();
  if (q.length < 2) return c.json({ data: [] });
  const digits = q.replace(/\D/g, "");
  const rows = (await c.get("db").query(
    `select id, display_name, username, email, country_code, contact_number, user_type, status, created_at
       from app.users
      where deleted_at is null and user_type in ('rider', 'driver')
        and (display_name ilike $1 or username ilike $1 or email ilike $1
             or ($2 <> '' and app.phone_digits(country_code, contact_number) like $3))
      order by id desc limit 20`,
    [`%${q.replace(/[%_]/g, "")}%`, digits.length >= 4 ? digits : "", `%${digits.replace(/^0+/, "")}%`])).rows;
  return c.json({ data: rows });
});

const ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789";
const tempPassword = () => {
  const b = crypto.getRandomValues(new Uint8Array(10));
  return [...b].map((x) => ALPHABET[x % ALPHABET.length]).join("");
};

/** Sets a one-time temporary password for a user who cannot use the emailed code. Shown once, never stored in plain text. */
adminUserRoutes.post("/admin/users/:id/reset-password", ...guard("user_account edit"), async (c) => {
  const db = c.get("db");
  const admin = c.get("user");
  const id = Number(c.req.param("id"));
  const u = (await db.query("select id, display_name, user_type from app.users where id = $1 and deleted_at is null and user_type in ('rider', 'driver')", [id])).rows[0];
  if (!u) return c.json({ message: "User not found" }, 404);
  const pw = tempPassword();
  const hash = await hashPassword(db, pw);
  await db.query("begin");
  try {
    await db.query("update app.users set password_hash = $2 where id = $1", [id, hash]);
    await db.query("delete from app.api_tokens where user_id = $1", [id]); // sign out everywhere
    await db.query("delete from app.password_reset_tokens where email = (select email from app.users where id = $1)", [id]);
    await db.query("insert into app.admin_audit (admin_id, action, target) values ($1, 'user_password_reset', $2)", [admin.id, String(id)]);
    await db.query("commit");
  } catch (e) {
    await db.query("rollback").catch(() => undefined);
    throw e;
  }
  c.header("Cache-Control", "no-store");
  return c.json({ message: "Temporary password set", temporary_password: pw, name: u.display_name });
});
