import { nationalNumber } from "../lib/phone";
import { Hono } from "hono";
import { z } from "zod";
import type { AppEnv } from "../env";
import { FOREIGN_KEY_VIOLATION, UNIQUE_VIOLATION, withDb } from "../db";
import { hashPassword, verifyPassword } from "../auth/password";
import { createToken } from "../auth/tokens";
import { requireAuth, USER_COLUMNS } from "../auth/middleware";
import { MESSAGES, readBody, validationFailed } from "../lib/legacy";
import { serializeUser } from "../serializers/user";

export const authRoutes = new Hono<AppEnv>();

const opt = (max = 255) =>
  z.preprocess((v) => (v === "" || v === undefined ? null : v), z.string().max(max).nullable());
const optNum = (min: number, max: number) =>
  z.preprocess(
    (v) => (v === "" || v === undefined || v === null ? null : Number(v)),
    z.number().min(min).max(max).nullable(),
  );
const optId = z.preprocess(
  (v) => (v === "" || v === undefined || v === null ? null : Number(v)),
  z.number().int().positive().nullable(),
);

const loginSchema = z.object({
  // New apps send "identifier" (phone, username or email); the old field name "email" still works.
  identifier: z.string().trim().max(255).optional(),
  email: z.string().trim().max(255).optional(),
  password: z.string({ error: "The password field is required." }).min(1, "The password field is required.").max(200),
  user_type: z.enum(["rider", "driver", "admin", "fleet"]).optional(),
  player_id: opt(),
  fcm_token: opt(1000),
  login_api: z.preprocess((v) => v === true || v === 1 || v === "1" || v === "true", z.boolean()),
});

function issues(err: z.ZodError): Record<string, string[]> {
  const out: Record<string, string[]> = {};
  for (const i of err.issues) (out[String(i.path[0] ?? "body")] ??= []).push(i.message);
  return out;
}

authRoutes.post("/login", withDb, async (c) => {
  const parsed = loginSchema.safeParse(await readBody(c));
  if (!parsed.success) return validationFailed(c, issues(parsed.error));
  const { password, player_id, fcm_token, login_api } = parsed.data;
  const identifier = (parsed.data.identifier || parsed.data.email || "").trim();
  if (!identifier) return validationFailed(c, { identifier: ["Enter your phone number or username."] });
  const userType = parsed.data.user_type;
  const db = c.get("db");

  // Phone, email or username: decide which column to match.
  let where: string;
  let arg: string;
  if (identifier.includes("@")) { where = "u.email = $1"; arg = identifier; }
  else if (/^[+\d][\d\s()-]{6,}$/.test(identifier)) {
    const digits = identifier.replace(/\D/g, "");
    // No country code typed: assume Nigeria. A leading 0 is the local trunk prefix.
    const full = identifier.startsWith("+") ? digits : digits.startsWith("234") && digits.length >= 12 ? digits : "234" + digits.replace(/^0+/, "");
    where = "app.phone_digits(u.country_code, u.contact_number) = $1"; arg = full;
  } else { where = "u.username = $1"; arg = identifier; }

  const found = await db.query(
    `select u.password_hash, ${USER_COLUMNS} from app.users u
      where ${where} and u.deleted_at is null ${userType ? "and u.user_type = $2" : ""}
      limit 1`,
    userType ? [arg, userType] : [arg],
  );
  const row = found.rows[0];
  const ok = await verifyPassword(db, password, row?.password_hash ?? null);
  if (!row || !ok) return c.json({ status: false, message: MESSAGES.authFailed }, 200);
  if (row.status === "banned") return c.json({ status: false, message: MESSAGES.accountBanned }, 200);
  if (login_api && row.user_type === "driver" && row.status !== "active") {
    return c.json({ status: false, message: MESSAGES.userNotActive }, 200);
  }

  // The unified app always opens in Passenger mode. A driver who is still online keeps Driver mode,
  // and the old driver app (which logs in as user_type driver) stays in Driver mode.
  const mode = row.user_type === "admin" || row.user_type === "fleet" ? row.active_mode
    : userType === "driver" && (row.roles as string[]).includes("driver") ? "driver"
    : row.is_online && row.active_mode === "driver" ? "driver" : "rider";
  const updated = await db.query(
    `update app.users set
        player_id = coalesce($2, player_id), fcm_token = coalesce($3, fcm_token), last_actived_at = now(), active_mode = $4
      where id = $1 returning player_id, fcm_token, last_actived_at, active_mode`,
    [row.id, player_id, fcm_token, mode],
  );
  Object.assign(row, updated.rows[0]);
  delete row.password_hash;
  const api_token = await createToken(db, row.id);
  return c.json({ status: true, data: { ...serializeUser(row), api_token, profile_image: null } });
});

const required = (name: string) => `The ${name} field is required.`;
const registerSchema = z.object({
  first_name: z.string({ error: required("first name") }).trim().min(1, required("first name")).max(100),
  last_name: z.string({ error: required("last name") }).trim().min(1, required("last name")).max(100),
  // Email is optional: riders sign up with a phone number.
  email: z.preprocess((v) => (v === "" || v == null ? null : v), z.string().trim().toLowerCase().email("The email must be a valid email address.").max(255).nullable()),
  username: z.preprocess((v) => (v === "" || v == null ? null : v), z.string().trim().min(3, "The username must be at least 3 characters.").max(100).nullable()),
  password: z.string({ error: required("password") }).min(8, "The password must be at least 8 characters.").max(72, "The password must not be greater than 72 characters."),
  user_type: z.enum(["rider", "driver"], { error: "The selected user type is invalid." }).default("rider"),
  contact_number: opt(30),
  country_code: opt(10),
  gender: z.preprocess((v) => (v === "" ? null : v), z.enum(["male", "female", "other"]).nullable().optional()),
  address: opt(500),
  player_id: opt(),
  fcm_token: opt(1000),
  uid: opt(),
  login_type: z.preprocess((v) => (v === "" ? null : v), z.enum(["app", "apple", "google", "otp"]).nullable().optional()),
  timezone: z.preprocess((v) => (v === "" || v == null ? "UTC" : v), z.string().max(64)),
  latitude: optNum(-90, 90),
  longitude: optNum(-180, 180),
  service_id: optId,
  partner_referral_code: opt(50),
  user_detail: z
    .object({
      car_model: opt(), car_color: opt(), car_plate_number: opt(), car_production_year: opt(10),
      work_address: opt(500), home_address: opt(500),
      work_latitude: optNum(-90, 90), work_longitude: optNum(-180, 180),
      home_latitude: optNum(-90, 90), home_longitude: optNum(-180, 180),
    })
    .partial()
    .optional(),
});

authRoutes.post("/register", withDb, async (c) => {
  const parsed = registerSchema.safeParse(await readBody(c));
  if (!parsed.success) return validationFailed(c, issues(parsed.error));
  const d = parsed.data;
  const db = c.get("db");
  if (!d.email && !d.contact_number) return validationFailed(c, { contact_number: ["Enter your phone number."] });
  if (d.contact_number) {
    const national = nationalNumber(d.country_code ?? "+234", d.contact_number);
    if (national.length < 6 || national.length > 13) return validationFailed(c, { contact_number: ["Enter a valid phone number."] });
    d.contact_number = national; // stored without the country code or leading 0
    d.country_code = (d.country_code ?? "+234").replace(/[^\d+]/g, "") || "+234";
    if (!d.country_code.startsWith("+")) d.country_code = "+" + d.country_code;
  }
  // No username typed: make a friendly one, e.g. ada4821.
  const baseName = (d.username ?? `${d.first_name}${d.last_name}`).toLowerCase().replace(/[^a-z0-9_.]/g, "").slice(0, 20) || "user";
  const usernameGiven = d.username != null;
  d.username = usernameGiven ? d.username : `${baseName}${Math.floor(1000 + Math.random() * 9000)}`;

  // Clients never choose their own role or status: only riders and drivers can self-register,
  // riders are active at once, drivers wait for admin approval.
  const status = d.user_type === "driver" ? "pending" : "active";
  const hash = await hashPassword(db, d.password);
  const referral = crypto.randomUUID().replace(/-/g, "").slice(0, 8).toUpperCase();

  try {
    await db.query("begin");
    const ins = await db.query(
      `insert into app.users (first_name, last_name, display_name, email, username, password_hash, uid, login_type,
          user_type, status, country_code, contact_number, gender, address, timezone, player_id, fcm_token,
          service_id, latitude, longitude, partner_referral_code, referral_code, roles, active_mode, last_actived_at)
       values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20,$21,$22,$23,$24, now())
       returning id`,
      [d.first_name, d.last_name, `${d.first_name} ${d.last_name}`.trim(), d.email, d.username, hash, d.uid,
        d.login_type ?? "app", d.user_type, status, d.country_code, d.contact_number, d.gender ?? null, d.address,
        d.timezone, d.player_id, d.fcm_token, d.service_id, d.latitude, d.longitude, d.partner_referral_code, referral,
        d.user_type === "driver" ? ["rider", "driver"] : ["rider"], d.user_type === "driver" ? "driver" : "rider"],
    );
    const id = ins.rows[0].id as number;
    const ud = d.user_detail;
    if (ud && Object.values(ud).some((v) => v != null)) {
      await db.query(
        `insert into app.user_details (user_id, car_model, car_color, car_plate_number, car_production_year,
            work_address, home_address, work_latitude, work_longitude, home_latitude, home_longitude)
         values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)`,
        [id, ud.car_model ?? null, ud.car_color ?? null, ud.car_plate_number ?? null, ud.car_production_year ?? null,
          ud.work_address ?? null, ud.home_address ?? null, ud.work_latitude ?? null, ud.work_longitude ?? null,
          ud.home_latitude ?? null, ud.home_longitude ?? null],
      );
    }
    if (d.user_type === "driver") {
      // Registering as a driver through the old flow files an application that waits for admin review.
      await db.query("insert into app.driver_profiles (user_id, status, service_id, submitted_at) values ($1, 'submitted', $2, now())", [id, d.service_id]);
    }
    if (d.user_type === "driver" && d.service_id) {
      await db.query("insert into app.driver_services (driver_id, service_id) values ($1,$2)", [id, d.service_id]);
    }
    const api_token = await createToken(db, id);
    const user = await db.query(`select ${USER_COLUMNS} from app.users u where u.id = $1`, [id]);
    await db.query("commit");
    return c.json({
      message: d.user_type === "driver" ? MESSAGES.driverSaved : MESSAGES.riderSaved,
      data: { ...serializeUser(user.rows[0]), api_token, profile_image: null },
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
    if (e.code === FOREIGN_KEY_VIOLATION) {
      return validationFailed(c, { service_id: ["The selected service id is invalid."] });
    }
    throw err;
  }
});

authRoutes.get("/logout", withDb, requireAuth, async (c) => {
  const db = c.get("db");
  const user = c.get("user");
  const clear = c.req.query("clear");
  if (clear === "player_id" || clear === "fcm_token") {
    await db.query(`update app.users set ${clear} = null where id = $1`, [user.id]);
  }
  // Signing out must not leave a driver showing as online.
  await db.query("update app.users set is_online = false, is_available = false where id = $1 and is_online", [user.id]);
  await db.query("delete from app.api_tokens where id = $1", [c.get("tokenId")]);
  return c.json({ message: MESSAGES.logout });
});
