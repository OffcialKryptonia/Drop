import { currencyInfo } from "./currency";
import { extraName } from "./extras";

type Row = Record<string, unknown>;
const money = (v: unknown) => Math.round(Number(v ?? 0) * 100) / 100;
const pad = (id: unknown) => String(Number(id)).padStart(6, "0");

/** Receipt numbers come from the trip id, so they never change and need no extra table. R = rider copy, D = driver copy. */
export const riderReceiptNo = (rideId: unknown) => `DROP-R-${pad(rideId)}`;
export const driverReceiptNo = (rideId: unknown) => `DROP-D-${pad(rideId)}`;

const trip = (r: Row) => ({
  ride_id: Number(r.id),
  issued_at: r.completed_at ?? null,
  started_at: r.started_at ?? null,
  service: r.service_name ?? null,
  pickup: r.pickup_address ?? null,
  dropoff: r.dropoff_address ?? null,
  distance: Number(r.distance),
  distance_unit: r.distance_unit,
  duration_minutes: Number(r.duration_minutes),
  currency: currencyInfo(r.currency as string),
  paid_with: r.paid_with ?? r.payment_method ?? null,
});

/** The fare as lines a person can read: base, distance and time, or the minimum fare, plus chosen extras. */
function fareLines(r: Row) {
  const b = (r.fare_breakdown ?? {}) as Record<string, unknown>;
  const lines: { label: string; amount: number }[] = [];
  const options = money(b.options_total);
  if (b.minimum_fare_applied) {
    lines.push({ label: "Minimum fare", amount: money(Number(r.fare) - options) });
  } else {
    lines.push({ label: "Base fare", amount: money(b.base_fare) });
    if (money(b.distance_charge) > 0) lines.push({ label: "Distance", amount: money(b.distance_charge) });
    if (money(b.time_charge) > 0) lines.push({ label: "Time", amount: money(b.time_charge) });
  }
  if (options > 0) lines.push({ label: "Extras", amount: options });
  return lines;
}

/** Paid extra charges (toll, parking, waiting) as receipt lines. */
const extraLines = (extras: Row[]) => extras.filter((e) => e.status === "paid").map((e) => ({ label: extraName(e), amount: money(e.amount) }));

export function riderReceipt(r: Row, extras: Row[] = []) {
  const cancellationFee = money(r.cancellation_fee);
  const extraTotal = money(extraLines(extras).reduce((a, l) => a + l.amount, 0));
  return {
    number: riderReceiptNo(r.id),
    kind: "rider" as const,
    ...trip(r),
    lines: [...fareLines(r), ...extraLines(extras)],
    total: money(Number(r.fare) + extraTotal),
    cancellation_fee: cancellationFee,
    driver: r.driver_id
      ? {
          name: [r.driver_first_name, r.driver_last_name].filter(Boolean).join(" "),
          vehicle: [r.vehicle_colour, r.vehicle_make, r.vehicle_model].filter(Boolean).join(" "),
          plate: r.vehicle_plate ?? null,
        }
      : null,
  };
}

export function driverReceipt(r: Row, extras: Row[] = []) {
  const paid = extras.filter((e) => e.status === "paid");
  const extraTotal = money(paid.reduce((a, e) => a + Number(e.amount), 0));
  const extraCommission = money(paid.reduce((a, e) => a + Number(e.commission ?? 0), 0));
  const fare = money(Number(r.fare) + extraTotal);
  const commission = money(Number(r.commission ?? 0) + extraCommission);
  const cashExtras = paid.filter((e) => e.paid_with === "cash").reduce((a, e) => a + Number(e.amount), 0);
  const paidWith = String(r.paid_with ?? r.payment_method ?? "cash");
  return {
    number: driverReceiptNo(r.id),
    kind: "driver" as const,
    ...trip(r),
    lines: [...fareLines(r), ...extraLines(extras)],
    fare,
    commission,
    earning: money(fare - commission),
    collect_cash: paidWith !== "wallet" || cashExtras > 0,
    cash_extras: money(cashExtras),
    rider_first_name: r.rider_first_name ?? null,
  };
}
