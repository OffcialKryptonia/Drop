import type { Client } from "pg";
import { postToWallet, toMoney } from "./wallet";

export type CommissionRule = { commission_type: string | null; admin_commission: number | string | null };

/** DROP's commission on a fare, rounded to kobo and never more than the fare. */
export function computeCommission(rule: CommissionRule, fare: number): string {
  const rate = Number(rule.admin_commission ?? 0);
  if (!(fare > 0) || !(rate > 0)) return "0.00";
  const raw = rule.commission_type === "fixed" ? rate : (fare * rate) / 100;
  return (Math.round(Math.min(raw, fare) * 100) / 100).toFixed(2);
}

/** The setting every driver is held to unless the ride type sets its own. */
export async function getGlobalMinBalance(db: Client): Promise<number> {
  const r = await db.query("select value from app.settings where key = 'driver_min_wallet_balance'");
  const n = Number(r.rows[0]?.value);
  return Number.isFinite(n) ? n : 0;
}

/** Can this driver take a trip of this ride type? (balance must be at least the minimum). */
export async function driverEligibility(db: Client, driverId: number, serviceId?: number | null) {
  const w = await db.query("select balance from app.wallets where user_id = $1 and kind = 'driver'", [driverId]);
  const balance = Number(w.rows[0]?.balance ?? 0);
  let min = await getGlobalMinBalance(db);
  if (serviceId) {
    const s = (await db.query("select min_wallet_balance from app.services where id = $1", [serviceId])).rows[0];
    if (s?.min_wallet_balance !== null && s?.min_wallet_balance !== undefined) min = Number(s.min_wallet_balance);
  }
  return { eligible: balance >= min, balance, minimum: min };
}

/**
 * Settles a finished trip against the driver's wallet. Call inside the caller's transaction.
 *  - cash trip: the rider paid the driver in hand, so DROP's commission is DEBITED from the driver's wallet.
 *  - wallet or card trip: DROP holds the money, so the driver is CREDITED fare minus commission.
 * Posting twice for the same ride changes nothing (idempotency key per ride).
 */
export async function settleDriverForRide(
  db: Client,
  ride: { id: number; driverId: number; serviceId: number; fare: number; paymentType: "cash" | "wallet" | "card" },
) {
  const svc = (await db.query("select commission_type, admin_commission from app.services where id = $1", [ride.serviceId])).rows[0];
  if (!svc) throw new Error("Unknown ride type");
  const commission = computeCommission(svc, ride.fare);
  const meta = { ride_id: ride.id, fare: ride.fare, commission, payment_type: ride.paymentType };

  if (ride.paymentType === "cash") {
    const amount = toMoney(commission);
    if (!amount) return { commission, posted: false }; // zero commission: nothing to take
    const r = await postToWallet(db, {
      userId: ride.driverId, direction: "debit", amount, kind: "commission", rideRequestId: ride.id,
      idempotencyKey: `commission:ride:${ride.id}`, description: "DROP commission on cash trip", meta, wallet: "driver", allowNegative: true,
    });
    return { commission, posted: !r.duplicate, balance: r.balance };
  }
  const earning = toMoney(Number(ride.fare) - Number(commission));
  if (!earning) return { commission, posted: false };
  const r = await postToWallet(db, {
    userId: ride.driverId, direction: "credit", amount: earning, kind: "ride_earning", rideRequestId: ride.id,
    idempotencyKey: `earning:ride:${ride.id}`, description: "Trip earnings", meta, wallet: "driver",
  });
  return { commission, posted: !r.duplicate, balance: r.balance };
}
