import type { Client } from "pg";

export class InsufficientFunds extends Error {}

type Post = {
  userId: number;
  direction: "credit" | "debit";
  amount: string; // decimal string with at most 2 places, e.g. "5000.00"
  kind: "topup" | "ride_payment" | "ride_earning" | "commission" | "withdrawal" | "refund" | "adjustment" | "legacy_import";
  idempotencyKey: string;
  /** Only for DRIVER wallets (commission, admin adjustments). Riders can never go below zero. */
  allowNegative?: boolean;
  description?: string;
  rideRequestId?: number;
  meta?: Record<string, unknown>;
};

/** Money as a 2-decimal string. Returns null for anything that is not a positive, sane amount. */
export function toMoney(v: unknown): string | null {
  const n = typeof v === "string" ? Number(v.replace(/,/g, "")) : typeof v === "number" ? v : NaN;
  if (!Number.isFinite(n) || n <= 0 || n > 100_000_000) return null;
  return (Math.round(n * 100) / 100).toFixed(2);
}

/**
 * Posts one ledger row and moves the balance. MUST run inside the caller's transaction
 * (begin ... commit). The wallet row is locked, and the unique idempotency key means a
 * replayed event returns {duplicate: true} and changes nothing.
 */
export async function postToWallet(db: Client, p: Post): Promise<{ duplicate: boolean; balance: string }> {
  await db.query("insert into app.wallets (user_id) values ($1) on conflict (user_id) do nothing", [p.userId]);
  const w = (await db.query("select id, balance from app.wallets where user_id = $1 for update", [p.userId])).rows[0];

  const seen = await db.query("select balance_after from app.wallet_ledger where idempotency_key = $1", [p.idempotencyKey]);
  if (seen.rowCount) return { duplicate: true, balance: seen.rows[0].balance_after };

  if (p.allowNegative) {
    const driver = (await db.query("select user_type from app.users where id = $1", [p.userId])).rows[0]?.user_type === "driver";
    if (!driver) throw new Error("Only driver wallets may go negative");
    await db.query("update app.wallets set allow_negative = true where id = $1 and not allow_negative", [w.id]);
  } else if (p.direction === "debit") {
    const ok = (await db.query("select $1::numeric <= $2::numeric as ok", [p.amount, w.balance])).rows[0].ok;
    if (!ok) throw new InsufficientFunds();
  }
  const updated = await db.query(
    `update app.wallets set balance = balance ${p.direction === "credit" ? "+" : "-"} $2::numeric where id = $1 returning balance`,
    [w.id, p.amount]);
  const balance = updated.rows[0].balance as string;
  await db.query(
    `insert into app.wallet_ledger (wallet_id, user_id, direction, amount, balance_after, kind, ride_request_id, description, idempotency_key, meta)
     values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10::jsonb)`,
    [w.id, p.userId, p.direction, p.amount, balance, p.kind, p.rideRequestId ?? null, p.description ?? null, p.idempotencyKey, JSON.stringify(p.meta ?? {})]);
  return { duplicate: false, balance };
}
