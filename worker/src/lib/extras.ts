import type { Client } from "pg";
import { currencyInfo, userCurrency } from "./currency";
import { InsufficientFunds, postToWallet, toMoney } from "./wallet";

type Row = Record<string, unknown>;

export const EXTRA_KINDS = ["toll", "parking", "waiting", "other"] as const;
export type ExtraKind = (typeof EXTRA_KINDS)[number];

export type ExtrasSettings = { enabled: boolean; max_percent: number; commission_percent: number; window_minutes: number };

/** Defaults: on, an extra can add up to 20% of the fare, DROP takes no commission on extras, 30 minutes to add and answer. */
export async function extrasSettings(db: Client): Promise<ExtrasSettings> {
  const v = ((await db.query("select value from app.settings where key = 'extras'")).rows[0]?.value ?? {}) as Record<string, unknown>;
  const num = (x: unknown, d: number, min: number, max: number) => {
    const n = Number(x);
    return Number.isFinite(n) ? Math.min(max, Math.max(min, n)) : d;
  };
  return {
    enabled: v.enabled !== false,
    max_percent: num(v.max_percent, 20, 0, 100),
    commission_percent: num(v.commission_percent, 0, 0, 100),
    window_minutes: Math.round(num(v.window_minutes, 30, 5, 240)),
  };
}

const cents = (n: number) => Math.round(n * 100) / 100;

export const extraView = (e: Row) => ({
  id: Number(e.id),
  ride_id: Number(e.ride_request_id),
  kind: e.kind,
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

/** Driver adds an extra charge to one of their finished trips. Not saved unless every rule passes. */
export async function proposeExtra(
  db: Client,
  p: { rideId: number; driverId: number; kind: ExtraKind; amount: number; note?: string },
): Promise<{ ok: true; extra: Row; rider_id: number } | Fail> {
  const s = await extrasSettings(db);
  if (!s.enabled) return { ok: false, code: "disabled", message: "Extra charges are switched off." };
  const ride = (await db.query("select id, rider_id, status, fare, currency, completed_at from app.ride_requests where id = $1 and driver_id = $2", [p.rideId, p.driverId])).rows[0];
  if (!ride || ride.status !== "completed") return { ok: false, code: "not_completed", message: "You can add an extra charge only to a trip you have completed." };
  const ageMin = (Date.now() - new Date(ride.completed_at as string).getTime()) / 60000;
  if (ageMin > s.window_minutes) return { ok: false, code: "window_closed", message: `Extra charges can be added within ${s.window_minutes} minutes of the trip ending.` };

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
      `insert into app.ride_extras (ride_request_id, driver_id, rider_id, kind, note, amount, currency, expires_at)
       values ($1, $2, $3, $4, $5, $6, $7, now() + make_interval(mins => $8::int)) returning *`,
      [p.rideId, p.driverId, ride.rider_id, p.kind, p.note?.trim() || null, p.amount.toFixed(2), String(ride.currency ?? "NGN").trim(), s.window_minutes],
    )
  ).rows[0];
  return { ok: true, extra: row, rider_id: Number(ride.rider_id) };
}

/** The passenger pays an extra from their wallet, or says they will pay cash. One transaction. */
export async function payExtra(db: Client, extraId: number, riderId: number, method: "wallet" | "cash"): Promise<{ ok: true; extra: Row } | Fail> {
  const s = await extrasSettings(db);
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
    const commission = cents((amount * s.commission_percent) / 100);
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

export async function expireExtras(db: Client): Promise<number> {
  return (await db.query("update app.ride_extras set status = 'expired', responded_at = now() where status = 'pending' and expires_at < now()")).rowCount ?? 0;
}

export const kindLabel = (k: unknown) => ({ toll: "Toll", parking: "Parking", waiting: "Waiting time", other: "Extra charge" } as Record<string, string>)[String(k)] ?? "Extra charge";
