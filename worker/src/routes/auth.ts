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
  email: z.string({ error: "The email field is required." }).trim().min(1, "The email field is required.").max(255),
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
  const { email, password, player_id, fcm_token, login_api } = parsed.data;
  const userType = parsed.data.user_type;
  const db = c.get("db");

  const found = await db.query(
    `select u.password_hash, ${USER_COLUMNS} from app.users u
      where u.email = $1 and u.deleted_at is null ${userType ? "and u.user_type = $2" : ""}
      limit 1`,
    userType ? [email, userType] : [email],
  );
  const row = found.rows[0];
  const ok = await verifyPassword(password, row?.password_hash ?? null);
  if (!row || !ok) return c.json({ status: false, message: MESSAGES.authFailed }, 200);
  if (row.status === "banned") return c.json({ status: false, message: MESSAGES.accountBanned }, 200);
  if (login_api && row.user_type === "driver" && row.status !== "active") {
    return c.json({ status: false, message: MESSAGES.userNotActive }, 200);
  }

  const updated = await db.query(
    `update app.users set
        player_id = coalesce($2, player_id), fcm_token = coalesce($3, fcm_token), last_actived_at = now()
      where id = $1 returning player_id, fcm_token, last_actived_at`,
    [row.id, player_id, fcm_token],
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
  email: z.string({ error: required("email") }).trim().toLowerCase().email("The email must be a valid email address.").max(255),
  username: z.string({ error: required("username") }).trim().min(1, required("username")).max(100),
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

  // Clients never choose their own role or status: only riders and drivers can self-register,
  // riders are active at once, drivers wait for admin approval.
  const status = d.user_type === "driver" ? "pending" : "active";
  const hash = await hashPassword(d.password);
  const referral = crypto.randomUUID().replace(/-/g, "").slice(0, 8).toUpperCase();

  try {
    await db.query("begin");
    const ins = await db.query(
      `insert into app.users (first_name, last_name, display_name, email, username, password_hash, uid, login_type,
          user_type, status, country_code, contact_number, gender, address, timezone, player_id, fcm_token,
          service_id, latitude, longitude, partner_referral_code, referral_code, last_actived_at)
       values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20,$21,$22, now())
       returning id`,
      [d.first_name, d.last_name, `${d.first_name} ${d.last_name}`.trim(), d.email, d.username, hash, d.uid,
        d.login_type ?? "app", d.user_type, status, d.country_code, d.contact_number, d.gender ?? null, d.address,
        d.timezone, d.player_id, d.fcm_token, d.service_id, d.latitude, d.longitude, d.partner_referral_code, referral],
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
      const field = e.constraint?.includes("username") ? "username" : "email";
      return validationFailed(c, { [field]: [`The ${field} has already been taken.`] });
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
  await db.query("delete from app.api_tokens where id = $1", [c.get("tokenId")]);
  return c.json({ message: MESSAGES.logout });
});
