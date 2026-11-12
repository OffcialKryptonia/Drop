import type { Client } from "pg";
import { postToWallet, toMoney } from "./wallet";

export type PayLinkSettings = { enabled: boolean; link_hours: number };

export async function getPayLinkSettings(db: Client): Promise<PayLinkSettings> {
  const row = (await db.query("select value from app.settings where key = 'paymyride'")).rows[0];
  return { enabled: true, link_hours: 6, ...(row?.value ?? {}) };
}

const OPEN = ["accepted", "arrived", "in_progress"];

/**
 * Someone paid this link through a gateway. MUST run inside the caller's transaction.
 * The money is added to the passenger's DROP wallet and the trip is set to pay from the wallet, so the normal
 * end-of-trip settlement takes it. If the trip is already over, the money simply stays in the passenger's wallet.
 */
export async function creditPaidLink(
  db: Client,
  link: { id: number; user_id: number; ride_request_id: number },
  paid: { amount: string; gateway: "korapay" | "pocketfi"; reference: string; payerName?: string | null },
): Promise<void> {
  await postToWallet(db, {
    userId: Number(link.user_id), direction: "credit", amount: paid.amount, kind: "paymyride", wallet: "rider",
    idempotencyKey: `paymyride:${paid.gateway}:${paid.reference}`, rideRequestId: Number(link.ride_request_id),
    description: paid.payerName ? `Ride paid by ${paid.payerName}` : "Ride paid by someone else",
    meta: { gateway: paid.gateway, reference: paid.reference },
  });
  await db.query("update app.ride_pay_links set status = 'paid', gateway = $2, paid_at = now() where id = $1 and status = 'pending'", [link.id, paid.gateway]);
  await db.query(
    "update app.ride_requests set payment_method = 'wallet' where id = $1 and status = any($2) and payment_method <> 'wallet'",
    [link.ride_request_id, OPEN]);
}

/**
 * A bank transfer reached the passenger's own wallet account (Pocketfi). If that covers an open pay link for their
 * trip, the link counts as paid. MUST run inside the caller's transaction, after the wallet was credited.
 */
export async function applyTransferToPayLink(db: Client, userId: number, credited: string): Promise<void> {
  const link = (await db.query(
    `select l.id, l.amount, l.ride_request_id from app.ride_pay_links l
       join app.ride_requests r on r.id = l.ride_request_id
      where l.user_id = $1 and l.status = 'pending' and l.expires_at > now() and r.status = any($2) and r.payment_method <> 'wallet'
      order by l.id desc limit 1`, [userId, OPEN])).rows[0];
  if (!link) return;
  const paid = toMoney(credited);
  if (!paid || Number(paid) < Number(link.amount)) return;
  const bal = (await db.query("select balance from app.wallets where user_id = $1 and kind = 'rider'", [userId])).rows[0];
  if (!bal || Number(bal.balance) < Number(link.amount)) return;
  await db.query("update app.ride_pay_links set status = 'paid', gateway = 'pocketfi', paid_at = now() where id = $1", [link.id]);
  await db.query("update app.ride_requests set payment_method = 'wallet' where id = $1", [link.ride_request_id]);
}
