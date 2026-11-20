import type { Client } from "pg";
import { currencyInfo, userCurrency } from "./currency";
import { computeCommission } from "./commission";
import { InsufficientFunds, postToWallet, toMoney } from "./wallet";

type Row = Record<string, unknown>;


export type ExtrasSettings = { enabled: boolean; max_percent: number; window_minutes: number };

/** Defaults: on, an extra can add up to 20% of the fare, the passenger has 10 minutes to answer. Commission is decided per charge type. */
export async function extrasSettings(db: Client): Promise<ExtrasSettings> {
  const v = ((await db.query("select value from app.settings where key = 'extras'")).rows[0]?.value ?? {}) as Record<string, unknown>;
  const num = (x: unknown, d: number, min: number, max: number) => {
    const n = Number(x);
    return Number.isFinite(n) ? Math.min(max, Math.max(min, n)) : d;
  };
  return {
    enabled: v.enabled !== false,
    max_percent: num(v.max_percent, 20, 0, 100),
    window_minutes: Math.round(num(v.window_minutes, 10, 1, 60)),
  };
}

const cents = (n: number) => Math.round(n * 100) / 100;

export type ExtraType = { id: number; name: string; active: boolean; take_commission: boolean; max_amount: number | null; sort_order: number };
export const typeView = (t: Row): ExtraType => ({
  id: Number(t.id), name: String(t.name), active: t.active !== false, take_commission: t.take_commission === true,
  max_amount: t.max_amount === null || t.max_amount === undefined ? null : Number(t.max_amount), sort_order: Number(t.sort_order ?? 0),
});
export async function extraTypes(db: Client, onlyActive: boolean): Promise<ExtraType[]> {
  return (await db.query(`select * from app.extra_charge_types ${onlyActive ? "where active" : ""} order by sort_order, id`)).rows.map(typeView);
}

/** What a person reads: the type name saved with the charge, or the old fixed label. */
export const extraName = (e: Row) => String(e.label ?? "").trim() || kindLabel(e.kind);

export const extraView = (e: Row) => ({
  id: Number(e.id),
  ride_id: Number(e.ride_request_id),
  kind: e.kind,
  label: extraName(e),
  note: e.note ?? null,
  amount: Number(e.amount),
  currency: currencyInfo(String(e.currency ?? "NGN").trim()),
  status: e.status,
  paid_with: e.paid_with ?? null,
  commission: Number(e.commission ?? 0),
  expires_at: e.expires_at,
  created_at: e.created_at,
});

type Fail = { ok: false; code: string; message: string; remaining?: number };

/** Driver adds an extra charge after accepting, while heading to the pickup. Locked once they arrive. Not saved unless every rule passes. */
export async function proposeExtra(
  db: Client,
  p: { rideId: number; driverId: number; typeId: number; amount: number; note?: string },
): Promise<{ ok: true; extra: Row; rider_id: number } | Fail> {
  const s = await extrasSettings(db);
  if (!s.enabled) return { ok: false, code: "disabled", message: "Extra charges are switched off." };
  const ride = (await db.query("select id, rider_id, status, fare, currency from app.ride_requests where id = $1 and driver_id = $2", [p.rideId, p.driverId])).rows[0];
  if (!ride || ride.status !== "accepted") return { ok: false, code: "wrong_stage", message: "An extra charge can be added only after you accept, before you arrive at the pickup." };

  const type = (await db.query("select * from app.extra_charge_types where id = $1", [p.typeId])).rows[0];
  if (!type || type.active === false) return { ok: false, code: "bad_type", message: "Choose what the charge is for." };
  if (type.max_amount !== null && p.amount > Number(type.max_amount)) {
    const sym0 = currencyInfo(String(ride.currency ?? "NGN").trim()).symbol;
    return { ok: false, code: "over_type_cap", message: `A ${String(type.name).toLowerCase()} charge can be at most ${sym0}${Number(type.max_amount).toLocaleString("en-NG")}.` };
  }
  const open = (await db.query("select coalesce(sum(amount) filter (where status in ('pending','paid')), 0) as used, count(*) filter (where status = 'pending') as pending from app.ride_extras where ride_request_id = $1", [p.rideId])).rows[0];
  if (Number(open.pending) > 0) return { ok: false, code: "pending_exists", message: "Wait for the passenger to answer your last extra charge." };
  const cap = cents((Number(ride.fare) * s.max_percent) / 100);
  const remaining = Math.max(0, cents(cap - Number(open.used)));
  const sym = currencyInfo(String(ride.currency ?? "NGN").trim()).symbol;
  if (p.amount > remaining) {
    return { ok: false, code: "over_cap", remaining, message: remaining > 0 ? `The most you can add is ${sym}${remaining.toLocaleString("en-NG")}.` : "No more extra charges can be added to this trip." };
  }
  const row = (
    await db.query(
      `insert into app.ride_extras (ride_request_id, driver_id, rider_id, kind, type_id, label, commission_applies, note, amount, currency, expires_at)
       values ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, now() + make_interval(mins => $11::int)) returning *`,
      [p.rideId, p.driverId, ride.rider_id, String(type.name).toLowerCase().replace(/[^a-z0-9]+/g, "_"), type.id, type.name, type.take_commission === true, p.note?.trim() || null, p.amount.toFixed(2), String(ride.currency ?? "NGN").trim(), s.window_minutes],
    )
  ).rows[0];
  return { ok: true, extra: row, rider_id: Number(ride.rider_id) };
}

/** The passenger pays an extra from their wallet, or says they will pay cash. One transaction. */
export async function payExtra(db: Client, extraId: number, riderId: number, method: "wallet" | "cash"): Promise<{ ok: true; extra: Row } | Fail> {
  await db.query("begin");
  try {
    const e = (await db.query("select * from app.ride_extras where id = $1 and rider_id = $2 for update", [extraId, riderId])).rows[0];
    if (!e) { await db.query("rollback"); return { ok: false, code: "not_found", message: "Extra charge not found." }; }
    if (e.status !== "pending") { await db.query("rollback"); return { ok: false, code: "not_pending", message: "This extra charge has already been answered." }; }
    if (new Date(e.expires_at as string).getTime() < Date.now()) {
      await db.query("update app.ride_extras set status = 'expired', responded_at = now() where id = $1", [extraId]);
      await db.query("commit");
      return { ok: false, code: "expired", message: "This extra charge has expired." };
    }
    const amount = Number(e.amount);
    // DROP's cut of an extra uses the ride type's own commission rule, only for types the admin marked as commissionable.
    let commission = 0;
    if (e.commission_applies === true) {
      const svc = (await db.query("select s.commission_type, s.admin_commission from app.ride_requests r join app.services s on s.id = r.service_id where r.id = $1", [e.ride_request_id])).rows[0];
      if (svc) commission = Number(computeCommission(svc, amount));
    }
    if (method === "wallet") {
      if ((await userCurrency(db, riderId)) !== String(e.currency).trim()) { await db.query("rollback"); return { ok: false, code: "currency", message: "Your wallet is in a different currency. Choose cash." }; }
      try {
        await postToWallet(db, {
          userId: riderId, direction: "debit", amount: amount.toFixed(2), kind: "ride_payment", rideRequestId: Number(e.ride_request_id),
          idempotencyKey: `extra_payment:${extraId}`, description: "Extra charge", wallet: "rider",
        });
      } catch (err) {
        if (err instanceof InsufficientFunds) { await db.query("rollback"); return { ok: false, code: "insufficient_funds", message: "Your wallet balance is too low. Top up or choose cash." }; }
        throw err;
      }
      const earning = toMoney(amount - commission);
      if (earning) {
        await postToWallet(db, {
          userId: Number(e.driver_id), direction: "credit", amount: earning, kind: "ride_earning", rideRequestId: Number(e.ride_request_id),
          idempotencyKey: `extra_earning:${extraId}`, description: "Extra charge", wallet: "driver",
        });
      }
    } else {
      const fee = toMoney(commission);
      if (fee) {
        await postToWallet(db, {
          userId: Number(e.driver_id), direction: "debit", amount: fee, kind: "commission", rideRequestId: Number(e.ride_request_id),
          idempotencyKey: `extra_commission:${extraId}`, description: "Commission on extra charge", wallet: "driver", allowNegative: true,
        });
      }
    }
    const done = (await db.query("update app.ride_extras set status = 'paid', paid_with = $2, commission = $3, responded_at = now() where id = $1 returning *", [extraId, method, commission.toFixed(2)])).rows[0];
    await db.query("commit");
    return { ok: true, extra: done };
  } catch (err) {
    await db.query("rollback").catch(() => {});
    throw err;
  }
}

/** Passenger declines (answered = declined) or driver withdraws (cancelled) a pending extra. */
export async function closeExtra(db: Client, extraId: number, who: { riderId?: number; driverId?: number }, status: "declined" | "cancelled"): Promise<Row | null> {
  const col = who.riderId ? "rider_id" : "driver_id";
  const id = who.riderId ?? who.driverId;
  return (await db.query(`update app.ride_extras set status = $3, responded_at = now() where id = $1 and ${col} = $2 and status = 'pending' returning *`, [extraId, id, status])).rows[0] ?? null;
}

/**
 * The ride was cancelled (by the passenger or the driver) before the trip started: close open extras and
 * give back anything already paid. Wallet payments are refunded from the driver's wallet; cash was never collected.
 */
export async function voidExtrasForRide(db: Client, rideId: number): Promise<void> {
  const rows = (await db.query("select * from app.ride_extras where ride_request_id = $1 and status in ('pending', 'paid') for update", [rideId])).rows;
  for (const e of rows) await reverseExtra(db, e);
}

/** Closes one pending/paid extra and reverses its money (wallet: refund the passenger, take it back from the driver). Call inside a transaction. */
export async function reverseExtra(db: Client, e: Row): Promise<void> {
  const id = Number(e.id);
  const rideId = Number(e.ride_request_id);
  if (e.status === "paid" && e.paid_with === "wallet") {
    const amount = Number(e.amount);
    await postToWallet(db, {
      userId: Number(e.rider_id), direction: "credit", amount: toMoney(amount) ?? "0", kind: "refund", rideRequestId: rideId,
      idempotencyKey: `extra_refund:${id}`, description: "Extra charge refunded", wallet: "rider",
    });
    const earning = toMoney(amount - Number(e.commission ?? 0));
    if (earning) {
      await postToWallet(db, {
        userId: Number(e.driver_id), direction: "debit", amount: earning, kind: "refund", rideRequestId: rideId,
        idempotencyKey: `extra_refund_debit:${id}`, description: "Extra charge refunded", wallet: "driver", allowNegative: true,
      });
    }
  } else if (e.status === "paid" && Number(e.commission ?? 0) > 0) {
    await postToWallet(db, {
      userId: Number(e.driver_id), direction: "credit", amount: toMoney(Number(e.commission)) ?? "0", kind: "adjustment", rideRequestId: rideId,
      idempotencyKey: `extra_commission_back:${id}`, description: "Commission on extra charge returned", wallet: "driver",
    });
  }
  await db.query("update app.ride_extras set status = 'cancelled', responded_at = now() where id = $1", [id]);
}

export async function expireExtras(db: Client): Promise<number> {
  return (await db.query("update app.ride_extras set status = 'expired', responded_at = now() where status = 'pending' and expires_at < now()")).rowCount ?? 0;
}

export const kindLabel = (k: unknown) => ({ toll: "Toll", parking: "Parking", waiting: "Waiting time", other: "Extra charge" } as Record<string, string>)[String(k)] ?? "Extra charge";
