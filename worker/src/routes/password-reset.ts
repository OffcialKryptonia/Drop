import { Hono } from "hono";
import type { AppEnv } from "../env";
import { withDb } from "../db";
import { hashPassword, verifyPassword } from "../auth/password";
import { requireAuth } from "../auth/middleware";
import { UNIQUE_VIOLATION } from "../db";
import { readBody, validationFailed } from "../lib/legacy";
import { sendEmail } from "../lib/email";

export const passwordResetRoutes = new Hono<AppEnv>();

const GENERIC = "If an account with that phone number, username or email has an email address saved, we sent a 6-digit code to it. It is valid for 15 minutes.";

const sha256 = async (s: string) =>
  [...new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(s)))].map((x) => x.toString(16).padStart(2, "0")).join("");
const same = (a: string, b: string) => {
  if (a.length !== b.length) return false;
  let d = 0;
  for (let i = 0; i < a.length; i++) d |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return d === 0;
};

/** Finds a user by phone, username or email, the same way login does. */
async function findUser(db: import("pg").Client, identifier: string) {
  let where: string, arg: string;
  if (identifier.includes("@")) { where = "email = $1"; arg = identifier; }
  else if (/^[+\d][\d\s()-]{6,}$/.test(identifier)) {
    const digits = identifier.replace(/\D/g, "");
    arg = identifier.startsWith("+") ? digits : digits.startsWith("234") && digits.length >= 12 ? digits : "234" + digits.replace(/^0+/, "");
    where = "app.phone_digits(country_code, contact_number) = $1";
  } else { where = "username = $1"; arg = identifier; }
  return (await db.query(`select id, email, first_name from app.users where ${where} and deleted_at is null limit 1`, [arg])).rows[0] as { id: number; email: string | null; first_name: string | null } | undefined;
}

passwordResetRoutes.post("/forgot-password", withDb, async (c) => {
  const db = c.get("db");
  const b = await readBody(c);
  const identifier = String(b.identifier ?? b.email ?? "").trim();
  if (!identifier) return validationFailed(c, { identifier: ["Enter your phone number, username or email."] });
  const u = await findUser(db, identifier);
  if (u?.email) {
    // At most 3 codes an hour per account.
    const recent = (await db.query("select count(*)::int n from app.password_reset_tokens where email = $1 and created_at > now() - interval '1 hour'", [u.email])).rows[0].n;
    if (recent < 3) {
      const code = String(100000 + (crypto.getRandomValues(new Uint32Array(1))[0] % 900000));
      await db.query("delete from app.password_reset_tokens where email = $1 and expires_at < now()", [u.email]);
      await db.query("insert into app.password_reset_tokens (email, token_hash) values ($1, $2)", [u.email, await sha256(`${u.email}:${code}`)]);
      const name = (u.first_name ?? "").trim() || "there";
      const sent = await sendEmail(db, c.env.SETTINGS_ENCRYPTION_KEY, {
        to: u.email, subject: "Your DROP password reset code",
        html: `<p>Hi ${name.replace(/[<>&]/g, "")},</p><p>Your DROP password reset code is:</p><p style="font-size:28px;font-weight:800;letter-spacing:4px">${code}</p><p>It is valid for 15 minutes. If you did not ask for this, you can ignore this email; your password has not changed.</p>`,
      });
      if (!sent) console.error("password reset email not sent for user", u.id);
    }
  }
  return c.json({ message: GENERIC });
});

passwordResetRoutes.post("/reset-password", withDb, async (c) => {
  const db = c.get("db");
  const b = await readBody(c);
  const identifier = String(b.identifier ?? "").trim();
  const code = String(b.code ?? "").replace(/\D/g, "");
  const password = String(b.password ?? "");
  if (!identifier) return validationFailed(c, { identifier: ["Enter your phone number, username or email."] });
  if (code.length !== 6) return validationFailed(c, { code: ["Enter the 6-digit code from your email."] });
  if (password.length < 8 || password.length > 72) return validationFailed(c, { password: ["The password must be 8 to 72 characters."] });
  const bad = () => validationFailed(c, { code: ["That code is wrong or has expired. Ask for a new one."] });

  const u = await findUser(db, identifier);
  if (!u?.email) return bad();
  const t = (await db.query("select id, token_hash, attempts from app.password_reset_tokens where email = $1 and expires_at > now() order by id desc limit 1", [u.email])).rows[0];
  if (!t || t.attempts >= 5) return bad();
  if (!same(await sha256(`${u.email}:${code}`), t.token_hash)) {
    await db.query("update app.password_reset_tokens set attempts = attempts + 1 where id = $1", [t.id]);
    return bad();
  }
  const hash = await hashPassword(db, password);
  await db.query("begin");
  try {
    await db.query("update app.users set password_hash = $2 where id = $1", [u.id, hash]);
    await db.query("delete from app.password_reset_tokens where email = $1", [u.email]);
    await db.query("delete from app.api_tokens where user_id = $1", [u.id]); // sign out everywhere
    await db.query("commit");
  } catch (e) {
    await db.query("rollback").catch(() => undefined);
    throw e;
  }
  return c.json({ message: "Password changed. Log in with your new password." });
});

/** Does this account have an email for password resets? */
passwordResetRoutes.get("/account/email", withDb, requireAuth, async (c) => {
  const e = (await c.get("db").query("select email from app.users where id = $1", [c.get("user").id])).rows[0]?.email as string | null;
  return c.json({ has_email: !!e, email: e ?? null });
});

/** Adds or changes the email used for password resets. Needs the current password, so a stolen session cannot redirect resets. */
passwordResetRoutes.post("/account/email", withDb, requireAuth, async (c) => {
  const db = c.get("db");
  const b = await readBody(c);
  const email = String(b.email ?? "").trim().toLowerCase();
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email) || email.length > 255) return validationFailed(c, { email: ["Enter a valid email address."] });
  const row = (await db.query("select password_hash from app.users where id = $1", [c.get("user").id])).rows[0];
  if (!(await verifyPassword(db, String(b.password ?? ""), row?.password_hash ?? null))) return validationFailed(c, { password: ["Your password is not correct."] });
  try {
    await db.query("update app.users set email = $2 where id = $1", [c.get("user").id, email]);
  } catch (err) {
    if ((err as { code?: string }).code === UNIQUE_VIOLATION) return validationFailed(c, { email: ["This email is already used by another account."] });
    throw err;
  }
  return c.json({ message: "Email saved. We will send password reset codes there." });
});
