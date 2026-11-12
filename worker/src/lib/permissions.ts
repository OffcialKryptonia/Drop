import type { Context, Next } from "hono";
import type { AppEnv } from "../env";
import { withDb } from "../db";
import { requireAuth } from "../auth/middleware";

/** Every module the admin can grant. Names follow the legacy pattern "<module> list|add|edit|delete". */
export const MODULES: { key: string; label: string; actions: string[] }[] = [
  { key: "service", label: "Ride types", actions: ["list", "add", "edit", "delete"] },
  { key: "service_option", label: "Ride options", actions: ["list", "add", "edit", "delete"] },
  { key: "region", label: "Regions", actions: ["list", "add", "edit", "delete"] },
  { key: "payment_gateway", label: "Payment methods", actions: ["list", "edit"] },
  { key: "driver_application", label: "Driver applications", actions: ["list", "edit"] },
  { key: "driver_wallet", label: "Driver wallets", actions: ["list", "edit"] },
  { key: "wallet_transfer", label: "Wallet transfers", actions: ["list", "edit"] },
  { key: "paymyride", label: "PayMyRide", actions: ["list", "edit"] },
  { key: "payout", label: "Driver payouts", actions: ["list", "edit"] },
  { key: "document", label: "Driver document types", actions: ["list", "edit"] },
  { key: "user_account", label: "User accounts (password reset)", actions: ["list", "edit"] },
  { key: "bank", label: "Banks", actions: ["list", "edit"] },
  { key: "map_settings", label: "Maps", actions: ["list", "edit"] },
  { key: "role", label: "Roles", actions: ["list", "add", "edit", "delete"] },
  { key: "subadmin", label: "Sub-admins", actions: ["list", "add", "edit", "delete"] },
];

export const ALL_PERMISSIONS = MODULES.flatMap((m) => m.actions.map((a) => `${m.key} ${a}`));

export type AdminAccess = { isSuper: boolean; permissions: Set<string> };

/** Loads the signed-in admin's role. Super admins (and admins with no role yet) have every permission. */
export async function loadAccess(c: Context<AppEnv>): Promise<AdminAccess> {
  const db = c.get("db");
  const user = c.get("user");
  const row = (await db.query(
    `select r.is_super,
            coalesce(array_agg(p.permission) filter (where p.permission is not null), '{}') as perms
       from app.users u
       left join app.admin_roles r on r.id = u.admin_role_id
       left join app.admin_role_permissions p on p.role_id = r.id
      where u.id = $1
      group by r.is_super`,
    [user.id],
  )).rows[0];
  const isSuper = !row || row.is_super === null || row.is_super === true;
  return { isSuper, permissions: new Set<string>(isSuper ? ALL_PERMISSIONS : row.perms) };
}

/** Admin-only route that also needs one permission, e.g. guard("service edit"). */
export const guard = (permission: string) => [
  withDb,
  requireAuth,
  async (c: Context<AppEnv>, next: Next) => {
    if (c.get("user").user_type !== "admin") return c.json({ message: "Forbidden" }, 403);
    const access = await loadAccess(c);
    if (!access.permissions.has(permission)) return c.json({ message: "You do not have permission to do this." }, 403);
    await next();
  },
] as const;

/** Records what an admin did. Detail holds field names and ids only, never secret values. */
export async function audit(c: Context<AppEnv>, action: string, target: string, detail: Record<string, unknown> = {}) {
  await c.get("db").query(
    "insert into app.admin_audit (admin_id, action, target, detail) values ($1,$2,$3,$4)",
    [c.get("user").id, action, target, JSON.stringify(detail)],
  );
}
