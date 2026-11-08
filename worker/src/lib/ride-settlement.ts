import type { Client } from "pg";
import { InsufficientFunds, postToWallet, toMoney } from "./wallet";
import { computeCommission, settleDriverForRide } from "./commission";

type Row = Record<string, unknown>;

/**
 * Finishes an in-progress trip: marks it completed (only once) and settles the money. Runs in one transaction.
 *  - wallet trip: rider wallet debited; if the balance dropped meanwhile, the trip is settled as cash instead.
 *  - cash trip: driver's wallet is debited the commission. Wallet trip: driver credited fare minus commission.
 * Returns null when the ride is not this driver's in-progress trip.
 */
export async function completeRide(db: Client, rideId: number, driverId: number): Promise<Row | null> {
  await db.query("begin");
  try {
    const r = (
      await db.query(
        `update app.ride_requests set status = 'completed', completed_at = now()
          where id = $1 and driver_id = $2 and status = 'in_progress' returning *`,
        [rideId, driverId],
      )
    ).rows[0];
    if (!r) {
      await db.query("rollback");
      return null;
    }
    const fare = Number(r.fare);
    let paidWith: "cash" | "wallet" = r.payment_method === "wallet" ? "wallet" : "cash";
    if (paidWith === "wallet") {
      const amount = toMoney(fare);
      try {
        if (amount) {
          await db.query("savepoint pay");
          await postToWallet(db, {
            userId: Number(r.rider_id), direction: "debit", amount, kind: "ride_payment", rideRequestId: rideId,
            idempotencyKey: `ride_payment:ride:${rideId}`, description: "Ride payment", wallet: "rider",
          });
        }
      } catch (e) {
        if (!(e instanceof InsufficientFunds)) throw e;
        await db.query("rollback to savepoint pay");
        paidWith = "cash"; // rider's wallet no longer covers the fare: driver collects cash
      }
    }
    const s = await settleDriverForRide(db, { id: rideId, driverId, serviceId: Number(r.service_id), fare, paymentType: paidWith });
    const done = (
      await db.query("update app.ride_requests set paid_with = $2, commission = $3 where id = $1 returning *", [rideId, paidWith, s.commission])
    ).rows[0];
    await db.query("update app.users set is_available = true where id = $1 and is_online", [driverId]);
    await db.query("commit");
    return done;
  } catch (e) {
    await db.query("rollback").catch(() => {});
    throw e;
  }
}

/**
 * Cancellation by the passenger after a driver accepted. A fee applies once the driver has arrived,
 * or the grace period after acceptance has passed. The fee comes from the rider's wallet (as much as it covers)
 * and the driver gets it minus DROP's commission. Returns the amount actually charged.
 */
export async function chargeCancellationFee(db: Client, ride: Row, graceSeconds: number): Promise<number> {
  const svc = (await db.query("select cancellation_fee, commission_type, admin_commission from app.services where id = $1", [ride.service_id])).rows[0];
  const fee = Number(svc?.cancellation_fee ?? 0);
  if (!(fee > 0) || !ride.driver_id) return 0;
  const waited = ride.accepted_at ? (Date.now() - new Date(ride.accepted_at as string).getTime()) / 1000 : 0;
  if (ride.status_before !== "arrived" && waited <= graceSeconds) return 0;

  const bal = Number((await db.query("select balance from app.wallets where user_id = $1 and kind = 'rider'", [ride.rider_id])).rows[0]?.balance ?? 0);
  const charge = Math.min(fee, bal);
  const amount = toMoney(charge);
  if (!amount) return 0;
  await db.query("begin");
  try {
    await postToWallet(db, {
      userId: Number(ride.rider_id), direction: "debit", amount, kind: "ride_payment", rideRequestId: Number(ride.id),
      idempotencyKey: `cancel_fee:ride:${ride.id}`, description: "Cancellation fee", wallet: "rider",
    });
    const commission = Number(computeCommission(svc, Number(amount)));
    const earning = toMoney(Number(amount) - commission);
    if (earning) {
      await postToWallet(db, {
        userId: Number(ride.driver_id), direction: "credit", amount: earning, kind: "ride_earning", rideRequestId: Number(ride.id),
        idempotencyKey: `cancel_earning:ride:${ride.id}`, description: "Cancellation fee", wallet: "driver",
      });
    }
    await db.query("update app.ride_requests set cancellation_fee = $2 where id = $1", [ride.id, amount]);
    await db.query("commit");
    return Number(amount);
  } catch (e) {
    await db.query("rollback").catch(() => {});
    throw e;
  }
}
