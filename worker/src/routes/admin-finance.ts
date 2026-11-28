import { Hono, type Context } from "hono";
import type { Client } from "pg";
import type { AppEnv } from "../env";
import { audit, guard } from "../lib/permissions";
import { validationFailed } from "../lib/legacy";
import { moneyList, parsePeriod, round2, toCsv, type Money, type Period } from "../lib/analytics";

/**
 * Financial intelligence. Every figure is computed on request from the authoritative records: the trip row for what was charged and how it
 * was paid, and the wallet ledger for where the money moved. No stored summary counter is read. Where the two disagree, the Reconciliation
 * report says so instead of picking a winner.
 */
export const adminFinanceRoutes = new Hono<AppEnv>();
type C = Context<AppEnv>;
type Row = Record<string, unknown>;
const n = (v: unknown) => Number(v ?? 0);
const intOrNull = (v: unknown) => (/^\d{1,15}$/.test(String(v ?? "")) ? Number(v) : null);
const CATEGORIES = ["standard", "airport_pickup", "airport_drop"] as const;
const METHODS = ["cash", "wallet", "card"] as const;
const CAT_SQL = "(case when r.airport_id is null then 'standard' when r.airport_direction = 'pickup' then 'airport_pickup' else 'airport_drop' end)";
const CAP = 20000;

type Filters = { region: number | null; service: number | null; category: string | null; method: string | null };
function readFilters(c: C): Filters | { error: Record<string, string[]> } {
  const category = c.req.query("category") || null, method = c.req.query("payment_method") || null;
  if (category && !(CATEGORIES as readonly string[]).includes(category)) return { error: { category: ["Choose standard, airport_pickup or airport_drop."] } };
  if (method && !(METHODS as readonly string[]).includes(method)) return { error: { payment_method: ["Choose cash, wallet or card."] } };
  return { region: intOrNull(c.req.query("region_id")), service: intOrNull(c.req.query("service_id")), category, method };
}
async function context(c: C) {
  const p = parsePeriod({ from: c.req.query("from"), to: c.req.query("to"), tz: c.req.query("tz") });
  if ("error" in p) return { err: validationFailed(c, { from: [p.error] }) };
  const f = readFilters(c);
  if ("error" in f) return { err: validationFailed(c, f.error) };
  const db = c.get("db");
  const b = (await db.query("select (($1::date)::timestamp at time zone $3) as s, ((($2::date) + 1)::timestamp at time zone $3) as e", [p.from, p.to, p.tz])).rows[0];
  return { db, p: p as Period, f, s: b.s as Date, e: b.e as Date };
}
/** Trip filters. The trip-level filters apply to anything tied to a trip; payment method applies to how the trip or extra was paid. */
const tripFilter = (f: Filters, withMethod = true) =>
  `and ($3::bigint is null or r.region_id = $3::bigint) and ($4::bigint is null or r.service_id = $4::bigint) and ($5::text is null or ${CAT_SQL} = $5::text)` +
  (withMethod ? " and ($6::text is null or r.paid_with = $6::text)" : "");
const args = (x: { s: Date; e: Date; f: Filters }) => [x.s, x.e, x.f.region, x.f.service, x.f.category, x.f.method];
const tripFiltered = (f: Filters) => f.region != null || f.service != null || f.category != null;
const byCur = (rows: Row[], key = "amount"): Money[] => moneyList(rows.map((r) => ({ currency: String(r.cur ?? "NGN"), amount: n(r[key]) })));
const periodOut = (p: Period, s: Date, e: Date) => ({ from: p.from, to: p.to, timezone: p.tz, days: p.days, starts_at: s.toISOString(), ends_at: e.toISOString() });

/** One row per completed trip in the period, with its commission read from the ledger. */
const RIDES_CTE = (f: Filters) => `
  with rl as (
    select r.id, r.fare, trim(r.currency) cur, r.paid_with, coalesce(r.commission, 0) stored_commission, r.completed_at, r.region_id, r.service_id,
           ${CAT_SQL} category,
           (select amount from app.wallet_ledger where idempotency_key = 'commission:ride:' || r.id) comm_row,
           (select amount from app.wallet_ledger where idempotency_key = 'ride_payment:ride:' || r.id) pay_row,
           (select amount from app.wallet_ledger where idempotency_key = 'earning:ride:' || r.id) earn_row
      from app.ride_requests r
     where r.status = 'completed' and r.completed_at >= $1 and r.completed_at < $2 ${tripFilter(f)}
  ), rc as (select rl.*, coalesce(comm_row, case when pay_row is not null then pay_row - coalesce(earn_row, 0) end, 0) as commission from rl)`;

adminFinanceRoutes.get("/admin/finance/summary", ...guard("finance list"), async (c) => {
  const x = await context(c);
  if (x.err) return x.err;
  const { db, p, f, s, e } = x;
  const a = args(x as { s: Date; e: Date; f: Filters });
  const filtered = tripFiltered(f);
  const notes: string[] = [];

  const rides = (await db.query(`${RIDES_CTE(f)} select cur, paid_with, count(*)::int rides, sum(fare)::float8 gross, sum(commission)::float8 commission from rc group by 1, 2 order by 1, 2`, a)).rows;
  const bySvc = (await db.query(
    `${RIDES_CTE(f)} select cur, coalesce(sv.name, '(deleted ride type)') as service, rc.category, count(*)::int rides, sum(fare)::float8 gross, sum(commission)::float8 commission
       from rc left join app.services sv on sv.id = rc.service_id group by 1, 2, 3 order by 1, 2, 3`, a)).rows;
  const missing = (await db.query(
    `${RIDES_CTE(f)} select count(*) filter (where abs(stored_commission - commission) > 0.01)::int mismatch, count(*)::int total from rc`, a)).rows[0];

  // Extra charges paid in the period (the payment-method filter applies to how the extra was paid; trip filters apply through the trip).
  const extras = (await db.query(
    `select trim(x.currency) cur, x.paid_with, count(*)::int n, sum(x.amount)::float8 amount, sum(x.commission)::float8 commission
       from app.ride_extras x join app.ride_requests r on r.id = x.ride_request_id
      where x.status = 'paid' and x.responded_at >= $1 and x.responded_at < $2
        and ($3::bigint is null or r.region_id = $3::bigint) and ($4::bigint is null or r.service_id = $4::bigint) and ($5::text is null or ${CAT_SQL} = $5::text)
        and ($6::text is null or x.paid_with = $6::text) group by 1, 2 order by 1, 2`, a)).rows;

  // Cancellation fees: always charged to the passenger's wallet. Platform share is what the passenger paid minus what the driver received.
  const fees = (await db.query(
    `select trim(w.currency) cur, count(*)::int n, sum(l.amount)::float8 charged,
            sum(l.amount - coalesce((select amount from app.wallet_ledger e where e.idempotency_key = 'cancel_earning:ride:' || l.ride_request_id), 0))::float8 commission
       from app.wallet_ledger l join app.wallets w on w.id = l.wallet_id join app.ride_requests r on r.id = l.ride_request_id
      where l.idempotency_key like 'cancel_fee:ride:%' and l.created_at >= $1 and l.created_at < $2
        and ($3::bigint is null or r.region_id = $3::bigint) and ($4::bigint is null or r.service_id = $4::bigint) and ($5::text is null or ${CAT_SQL} = $5::text)
        and ($6::text is null or $6::text = 'wallet') group by 1 order by 1`, a)).rows;

  // Wallet movements by kind. Trip filters keep only rows tied to a matching trip; the payment-method filter does not apply here.
  const walletSql = filtered
    ? `select trim(w.currency) cur, w.kind wallet, l.kind, l.direction, count(*)::int n, sum(l.amount)::float8 amount from app.wallet_ledger l join app.wallets w on w.id = l.wallet_id
        join app.ride_requests r on r.id = l.ride_request_id where l.created_at >= $1 and l.created_at < $2 ${tripFilter(f, false)} group by 1, 2, 3, 4 order by 1, 2, 3, 4`
    : `select trim(w.currency) cur, w.kind wallet, l.kind, l.direction, count(*)::int n, sum(l.amount)::float8 amount from app.wallet_ledger l join app.wallets w on w.id = l.wallet_id
        where l.created_at >= $1 and l.created_at < $2 group by 1, 2, 3, 4 order by 1, 2, 3, 4`;
  const wallet = (await db.query(walletSql, filtered ? a.slice(0, 5) : a.slice(0, 2))).rows;

  // Refunds and reversals, by what they were.
  const refundSql = `select trim(w.currency) cur, case when l.idempotency_key like 'extra_refund:%' then 'extra_refunded_to_passenger'
                                                        when l.idempotency_key like 'extra_refund_debit:%' then 'extra_taken_back_from_driver'
                                                        when l.idempotency_key like 'extra_commission_back:%' then 'extra_commission_returned'
                                                        when l.idempotency_key like 'withdraw-refund:%' then 'payout_declined_returned_to_driver' else 'other_refund' end as what,
                            count(*)::int n, sum(l.amount)::float8 amount
                       from app.wallet_ledger l join app.wallets w on w.id = l.wallet_id ${filtered ? "join app.ride_requests r on r.id = l.ride_request_id" : ""}
                      where l.kind = 'refund' and l.created_at >= $1 and l.created_at < $2 ${filtered ? tripFilter(f, false) : ""} group by 1, 2 order by 1, 2`;
  const refunds = (await db.query(refundSql, filtered ? a.slice(0, 5) : a.slice(0, 2))).rows;

  // Online payments: money that arrived through a payment provider. Not tied to trips, so trip filters do not apply.
  const online = filtered || f.method ? null : (await db.query(
    `select provider, status, count(*)::int n, sum(amount)::float8 amount, sum(coalesce(fee, 0))::float8 fee
       from app.payment_events where created_at >= $1 and created_at < $2 group by 1, 2 order by 1, 2`, a.slice(0, 2))).rows;
  if (filtered || f.method) notes.push("Online payments, payouts and liabilities are not tied to trips, so they are left out when a trip or payment-method filter is on.");

  const payouts = filtered || f.method ? null : (await db.query(
    `select trim(currency) cur, status, count(*)::int n, sum(amount)::float8 amount from app.withdraw_requests where created_at >= $1 and created_at < $2 group by 1, 2 order by 1, 2`, a.slice(0, 2))).rows;
  const liabilities = filtered || f.method ? null : {
    pending_payouts: byCur((await db.query("select trim(currency) cur, sum(amount)::float8 amount, count(*)::int n from app.withdraw_requests where status = 'pending' group by 1")).rows),
    pending_payout_count: n((await db.query("select count(*)::int n from app.withdraw_requests where status = 'pending'")).rows[0].n),
    driver_wallet_balances_owed_to_drivers: byCur((await db.query("select trim(currency) cur, sum(balance)::float8 amount from app.wallets where kind = 'driver' and balance > 0 group by 1")).rows),
    driver_wallet_balances_owed_by_drivers: byCur((await db.query("select trim(currency) cur, sum(-balance)::float8 amount from app.wallets where kind = 'driver' and balance < 0 group by 1")).rows),
    rider_wallet_balances: byCur((await db.query("select trim(currency) cur, sum(balance)::float8 amount from app.wallets where kind = 'rider' and balance > 0 group by 1")).rows),
    as_of: new Date().toISOString(),
  };

  const sum = (rows: Row[], k: string, pred: (r: Row) => boolean = () => true) => moneyList(rows.filter(pred).map((r) => ({ currency: String(r.cur), amount: n(r[k]) })));
  const gross = sum(rides, "gross"), com = sum(rides, "commission");
  const extraCom = sum(extras, "commission"), feeCom = sum(fees, "commission");
  const revenue = moneyList([...com, ...extraCom, ...feeCom]);
  const driverEarn = moneyList([
    ...gross, ...com.map((m) => ({ currency: m.currency, amount: -m.amount })),
    ...sum(extras, "amount").map((m) => m), ...extraCom.map((m) => ({ currency: m.currency, amount: -m.amount })),
    ...sum(fees, "charged"), ...feeCom.map((m) => ({ currency: m.currency, amount: -m.amount })),
  ]);
  const cashRides = sum(rides, "gross", (r) => r.paid_with === "cash");
  const methods = ["cash", "wallet", "card"].map((m) => ({
    method: m, rides: rides.filter((r) => r.paid_with === m).reduce((t, r) => t + n(r.rides), 0), gross: sum(rides, "gross", (r) => r.paid_with === m), commission: sum(rides, "commission", (r) => r.paid_with === m),
    extras: sum(extras, "amount", (r) => r.paid_with === m),
  })).filter((m) => m.rides || m.gross.length || m.extras.length);

  return c.json({
    status: true, period: periodOut(p, x.s, x.e), filters: f, notes,
    definitions: {
      gross_ride_value: "Fares of trips completed in the period, from the trip record.",
      platform_commission: "Commission on those trips, read from the wallet ledger (cash trips: the commission debited from the driver; wallet trips: the passenger's payment minus the driver's earning).",
      platform_revenue: "Trip commission plus commission on paid extra charges plus the platform share of cancellation fees. Gateway fees are not deducted.",
      driver_earnings: "Fares minus commission on trips, plus paid extras and cancellation fees minus their commission. Cash is collected by the driver; DROP does not record the handover.",
    },
    rides: { completed: rides.reduce((t, r) => t + n(r.rides), 0), gross_ride_value: gross, platform_commission: com, driver_earnings_on_trips: moneyList([...gross, ...com.map((m) => ({ currency: m.currency, amount: -m.amount }))]),
      by_service: bySvc.map((r) => ({ currency: r.cur, ride_type: r.service, category: r.category, rides: n(r.rides), gross: round2(r.gross), commission: round2(r.commission) })),
      stored_commission_mismatches: n(missing?.mismatch) },
    platform_revenue: { total: revenue, from_trips: com, from_extras: extraCom, from_cancellation_fees: feeCom },
    driver_earnings: driverEarn,
    payment_method_breakdown: methods,
    cash_payments: { trip_fares_paid_in_cash: cashRides, extras_paid_in_cash: sum(extras, "amount", (r) => r.paid_with === "cash"), note: "Collected by drivers. DROP does not record the cash handover; commission on cash trips is debited from the driver's wallet." },
    extra_charges: { count: extras.reduce((t, r) => t + n(r.n), 0), paid: sum(extras, "amount"), commission: extraCom, by_method: extras.map((r) => ({ currency: r.cur, paid_with: r.paid_with, count: n(r.n), amount: round2(r.amount) })) },
    cancellation_fees: { count: fees.reduce((t, r) => t + n(r.n), 0), charged: sum(fees, "charged"), platform_share: feeCom },
    refunds: refunds.map((r) => ({ currency: r.cur, what: r.what, count: n(r.n), amount: round2(r.amount) })),
    wallet_transactions: wallet.map((r) => ({ currency: r.cur, wallet: r.wallet, kind: r.kind, direction: r.direction, count: n(r.n), amount: round2(r.amount) })),
    online_payments: online ? online.map((r) => ({ provider: r.provider, status: r.status, count: n(r.n), amount: round2(r.amount), fee: round2(r.fee) })) : { available: false, reason: "Not tied to trips." },
    payouts: payouts ? payouts.map((r) => ({ currency: r.cur, status: r.status, count: n(r.n), amount: round2(r.amount) })) : { available: false, reason: "Not tied to trips." },
    outstanding_liabilities: liabilities ?? { available: false, reason: "Not tied to trips." },
  });
});

// ---------------------------------------------------------------------------------------------------------------------
// Reconciliation: where the trip record and the ledger disagree. Each check lists up to 20 examples.
// ---------------------------------------------------------------------------------------------------------------------
type Check = { id: string; title: string; why: string; count: number; sample: Row[]; scope: "period" | "now" };
async function reconcile(db: Client, s: Date, e: Date, limit = 20): Promise<Check[]> {
  const q = async (id: string, title: string, why: string, scope: "period" | "now", body: string, params: unknown[]): Promise<Check> => {
    const total = Number((await db.query(`select count(*)::int n from (${body}) t`, params)).rows[0].n);
    const sample = total ? (await db.query(`select * from (${body}) t order by 1 limit ${limit}`, params)).rows : [];
    return { id, title, why, count: total, sample, scope };
  };
  const done = "r.status = 'completed' and r.completed_at >= $1 and r.completed_at < $2";
  return [
    await q("wallet_trip_without_payment", "Wallet-paid trips with no passenger payment in the ledger", "A trip says the passenger paid from their wallet, but no ride_payment ledger row exists.", "period",
      `select r.id as ride_id, r.fare::float8, r.completed_at from app.ride_requests r where ${done} and r.paid_with = 'wallet' and not exists (select 1 from app.wallet_ledger l where l.idempotency_key = 'ride_payment:ride:' || r.id)`, [s, e]),
    await q("payment_amount_differs_from_fare", "Passenger payment differs from the trip fare", "The ledger amount for a wallet trip is not the fare on the trip.", "period",
      `select r.id as ride_id, r.fare::float8, l.amount::float8 as ledger_amount from app.ride_requests r join app.wallet_ledger l on l.idempotency_key = 'ride_payment:ride:' || r.id where ${done} and r.paid_with = 'wallet' and abs(l.amount - r.fare) > 0.01`, [s, e]),
    await q("cash_trip_commission_missing", "Cash trips with commission recorded but not debited from the driver", "The trip carries a commission, but the driver's wallet was never charged for it.", "period",
      `select r.id as ride_id, r.commission::float8 from app.ride_requests r where ${done} and r.paid_with = 'cash' and coalesce(r.commission, 0) > 0 and not exists (select 1 from app.wallet_ledger l where l.idempotency_key = 'commission:ride:' || r.id)`, [s, e]),
    await q("wallet_trip_earning_missing", "Wallet trips where the driver was not credited", "The passenger paid from their wallet, but the driver's earning is missing from the ledger.", "period",
      `select r.id as ride_id, r.fare::float8, r.commission::float8 from app.ride_requests r where ${done} and r.paid_with = 'wallet' and r.fare - coalesce(r.commission, 0) > 0 and not exists (select 1 from app.wallet_ledger l where l.idempotency_key = 'earning:ride:' || r.id)`, [s, e]),
    await q("commission_differs_from_ledger", "Commission on the trip differs from the ledger", "The commission stored on the trip does not match what the ledger moved.", "period",
      `select r.id as ride_id, coalesce(r.commission, 0)::float8 as stored_commission,
              coalesce((select amount from app.wallet_ledger where idempotency_key = 'commission:ride:' || r.id),
                       (select p.amount - coalesce((select amount from app.wallet_ledger where idempotency_key = 'earning:ride:' || r.id), 0) from app.wallet_ledger p where p.idempotency_key = 'ride_payment:ride:' || r.id), 0)::float8 as ledger_commission
         from app.ride_requests r where ${done}
          and abs(coalesce(r.commission, 0) - coalesce((select amount from app.wallet_ledger where idempotency_key = 'commission:ride:' || r.id),
                       (select p.amount - coalesce((select amount from app.wallet_ledger where idempotency_key = 'earning:ride:' || r.id), 0) from app.wallet_ledger p where p.idempotency_key = 'ride_payment:ride:' || r.id), 0)) > 0.01`, [s, e]),
    await q("wallet_balance_differs_from_ledger", "Wallet balance differs from its ledger", "A wallet's balance is not the balance after its last ledger row. Checked for every wallet, as of now.", "now",
      `select w.id as wallet_id, w.user_id, w.kind, w.balance::float8, coalesce((select balance_after from app.wallet_ledger where wallet_id = w.id order by id desc limit 1), 0)::float8 as ledger_balance
         from app.wallets w where w.balance <> coalesce((select balance_after from app.wallet_ledger where wallet_id = w.id order by id desc limit 1), 0) and $1::timestamptz is not null and $2::timestamptz is not null`, [s, e]),
    await q("ledger_not_adding_up", "Ledger credits minus debits differ from the wallet balance", "Adding every credit and subtracting every debit does not give the wallet balance. Checked for every wallet, as of now.", "now",
      `select w.id as wallet_id, w.user_id, w.kind, w.balance::float8, x.net::float8 as ledger_net
         from app.wallets w join (select wallet_id, sum(case when direction = 'credit' then amount else -amount end) net from app.wallet_ledger group by 1) x on x.wallet_id = w.id
        where w.balance <> x.net and $1::timestamptz is not null and $2::timestamptz is not null`, [s, e]),
    await q("online_payment_not_credited", "Provider payments marked credited with no wallet credit", "A payment event says the wallet was credited, but no top-up ledger row exists.", "period",
      `select pe.id as payment_event_id, pe.provider, pe.provider_reference, pe.amount::float8 from app.payment_events pe
        where pe.status = 'credited' and pe.provider = 'pocketfi' and pe.created_at >= $1 and pe.created_at < $2 and not exists (select 1 from app.wallet_ledger l where l.idempotency_key = 'pocketfi:' || pe.provider_reference)`, [s, e]),
    await q("online_payment_flagged", "Provider payments flagged for attention", "Payments that arrived but could not be matched or credited automatically.", "period",
      `select pe.id as payment_event_id, pe.provider, pe.provider_reference, pe.amount::float8, pe.note from app.payment_events pe where pe.status = 'flagged' and pe.created_at >= $1 and pe.created_at < $2`, [s, e]),
    await q("payout_request_not_debited", "Payout requests with no wallet debit", "A payout was requested but the driver's wallet was never debited.", "period",
      `select w.id as payout_id, w.user_id, w.amount::float8, w.status from app.withdraw_requests w where w.created_at >= $1 and w.created_at < $2 and not exists (select 1 from app.wallet_ledger l where l.idempotency_key = 'withdraw:' || w.id)`, [s, e]),
    await q("declined_payout_not_returned", "Declined payouts not returned to the driver", "A payout was declined but the money was never put back in the driver's wallet.", "period",
      `select w.id as payout_id, w.user_id, w.amount::float8 from app.withdraw_requests w where w.status = 'declined' and w.created_at >= $1 and w.created_at < $2 and not exists (select 1 from app.wallet_ledger l where l.idempotency_key = 'withdraw-refund:' || w.id)`, [s, e]),
    await q("wallet_extra_not_paid_in_ledger", "Wallet-paid extra charges with no passenger payment", "An extra charge says it was paid from the wallet, but the ledger has no matching payment.", "period",
      `select x.id as extra_id, x.ride_request_id, x.amount::float8 from app.ride_extras x where x.status = 'paid' and x.paid_with = 'wallet' and x.responded_at >= $1 and x.responded_at < $2 and not exists (select 1 from app.wallet_ledger l where l.idempotency_key = 'extra_payment:' || x.id)`, [s, e]),
  ];
}

adminFinanceRoutes.get("/admin/finance/reconciliation", ...guard("finance list"), async (c) => {
  const x = await context(c);
  if (x.err) return x.err;
  const checks = await reconcile(x.db, x.s, x.e);
  const issues = checks.filter((k) => k.count > 0);
  return c.json({
    status: true, period: periodOut(x.p, x.s, x.e), generated_at: new Date().toISOString(),
    clean: issues.length === 0, issue_count: issues.reduce((t, k) => t + k.count, 0), checks,
    note: "Checks marked 'now' look at every wallet at this moment, whatever the period. Nothing here changes any record.",
  });
});

// ---------------------------------------------------------------------------------------------------------------------
// CSV export. Needs "finance export", is rate limited by the row cap, contains ids rather than names, phones or bank accounts, and is audited.
// ---------------------------------------------------------------------------------------------------------------------
adminFinanceRoutes.get("/admin/finance/export", ...guard("finance export"), async (c) => {
  const x = await context(c);
  if (x.err) return x.err;
  const { db, p, f, s, e } = x;
  const report = c.req.query("report") ?? "";
  const a = args(x as { s: Date; e: Date; f: Filters });
  let columns: { key: string; label: string }[] = [];
  let rows: Row[] = [];
  if (report === "rides") {
    columns = [["ride_id", "Trip"], ["completed_at", "Completed at"], ["region_id", "Region"], ["ride_type", "Ride type"], ["category", "Category"], ["paid_with", "Paid with"], ["currency", "Currency"], ["fare", "Fare"], ["commission", "Commission (ledger)"], ["driver_earnings", "Driver earnings"], ["stored_commission", "Commission on trip"]].map(([key, label]) => ({ key, label }));
    rows = (await db.query(
      `${RIDES_CTE(f)} select rc.id as ride_id, rc.completed_at, rc.region_id, coalesce(sv.name, '') as ride_type, rc.category, rc.paid_with, rc.cur as currency, rc.fare::float8 as fare,
              rc.commission::float8 as commission, (rc.fare - rc.commission)::float8 as driver_earnings, rc.stored_commission::float8 as stored_commission
         from rc left join app.services sv on sv.id = rc.service_id order by rc.completed_at, rc.id limit ${CAP + 1}`, a)).rows;
  } else if (report === "ledger") {
    columns = [["id", "Entry"], ["created_at", "Time"], ["wallet", "Wallet"], ["user_id", "User"], ["direction", "Direction"], ["kind", "Kind"], ["currency", "Currency"], ["amount", "Amount"], ["balance_after", "Balance after"], ["ride_request_id", "Trip"], ["description", "Description"]].map(([key, label]) => ({ key, label }));
    const filtered = tripFiltered(f);
    rows = (await db.query(
      `select l.id, l.created_at, w.kind as wallet, l.user_id, l.direction, l.kind, trim(w.currency) as currency, l.amount::float8 as amount, l.balance_after::float8 as balance_after, l.ride_request_id, l.description
         from app.wallet_ledger l join app.wallets w on w.id = l.wallet_id ${filtered ? "join app.ride_requests r on r.id = l.ride_request_id" : ""}
        where l.created_at >= $1 and l.created_at < $2 ${filtered ? tripFilter(f, false) : ""} order by l.id limit ${CAP + 1}`, filtered ? a.slice(0, 5) : a.slice(0, 2))).rows;
  } else if (report === "payouts") {
    columns = [["id", "Payout"], ["created_at", "Requested"], ["user_id", "Driver"], ["currency", "Currency"], ["amount", "Amount"], ["status", "Status"], ["processed_at", "Processed"], ["bank_name", "Bank"]].map(([key, label]) => ({ key, label }));
    rows = (await db.query(`select id, created_at, user_id, trim(currency) as currency, amount::float8 as amount, status, processed_at, bank_name from app.withdraw_requests where created_at >= $1 and created_at < $2 order by id limit ${CAP + 1}`, a.slice(0, 2))).rows;
  } else if (report === "reconciliation") {
    columns = [["check", "Check"], ["reference", "Reference"], ["detail", "Detail"]].map(([key, label]) => ({ key, label }));
    for (const k of await reconcile(db, s, e, 2000)) for (const r of k.sample) rows.push({ check: k.title, reference: Object.entries(r).filter(([key]) => /(_id|^id)$/.test(key)).map(([key, v]) => `${key}=${v}`).join(" "), detail: JSON.stringify(r) });
  } else return validationFailed(c, { report: ["Choose rides, ledger, payouts or reconciliation."] });
  const truncated = rows.length > CAP;
  if (truncated) rows = rows.slice(0, CAP);
  await audit(c, "finance_export", report, { from: p.from, to: p.to, timezone: p.tz, filters: f, rows: rows.length, truncated });
  const name = `drop-${report}-${p.from}_to_${p.to}.csv`;
  return new Response(toCsv(columns, rows), { headers: { "Content-Type": "text/csv; charset=utf-8", "Content-Disposition": `attachment; filename="${name}"`, "Cache-Control": "no-store", "X-Rows": String(rows.length), "X-Truncated": truncated ? "yes" : "no" } });
});
