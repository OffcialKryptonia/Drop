import type { MiddlewareHandler } from "hono";
import type { Client } from "pg";
import type { AppEnv } from "../env";
import { driverEligibility } from "./commission";

export type ModeBlock = { code: "not_driver" | "not_approved" | "suspended" | "rejected" | "account_inactive"; message: string };

/**
 * May this person use Driver mode? Approval and account state only. The wallet minimum and expired
 * documents do NOT block the switch (a driver must reach the wallet to top up), they block going online.
 */
export async function driverModeBlock(db: Client, userId: number): Promise<ModeBlock | null> {
  const r = (await db.query(
    `select u.status as user_status, 'driver' = any(u.roles) as has_role, p.status as profile_status
       from app.users u left join app.driver_profiles p on p.user_id = u.id where u.id = $1 and u.deleted_at is null`, [userId])).rows[0];
  if (!r || !r.has_role || !r.profile_status) return { code: "not_driver", message: "Apply to drive first, from Online registration." };
  switch (r.profile_status) {
    case "approved": return r.user_status === "active" ? null : { code: "account_inactive", message: "Your account is not active." };
    case "suspended": return { code: "suspended", message: "Your driver account is suspended. Contact support." };
    case "rejected": return { code: "rejected", message: "Your driver application was not approved." };
    default: return { code: "not_approved", message: "Your driver application is still being reviewed." };
  }
}

export type OnlineBlock = { code: "wallet_below_minimum" | "documents_expired"; message: string; minimum?: number; balance?: number };

/** Going online needs a wallet at or above the minimum and no expired required documents. */
export async function driverOnlineBlock(db: Client, userId: number, serviceId?: number | null): Promise<OnlineBlock | null> {
  const expired = (await db.query(
    `select 1 from app.driver_documents dd join app.documents d on d.id = dd.document_id
      where dd.driver_id = $1 and d.is_required and dd.expire_date is not null and dd.expire_date < current_date limit 1`, [userId])).rowCount;
  if (expired) return { code: "documents_expired", message: "A required document has expired. Upload a new one to go online." };
  const e = await driverEligibility(db, userId, serviceId);
  if (!e.eligible) return { code: "wallet_below_minimum", message: `Top up your wallet to at least ${e.minimum} to go online.`, minimum: e.minimum, balance: e.balance };
  return null;
}

/** Route guard: only approved drivers in good standing. The server decides; the app only hides the menu. */
export const requireApprovedDriver: MiddlewareHandler<AppEnv> = async (c, next) => {
  const block = await driverModeBlock(c.get("db"), c.get("user").id);
  if (block) return c.json({ status: false, ...block }, 403);
  await next();
};
