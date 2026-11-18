import { currencyInfo } from "./currency";

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

export function riderReceipt(r: Row) {
  const cancellationFee = money(r.cancellation_fee);
  return {
    number: riderReceiptNo(r.id),
    kind: "rider" as const,
    ...trip(r),
    lines: fareLines(r),
    total: money(r.fare),
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

export function driverReceipt(r: Row) {
  const fare = money(r.fare);
  const commission = money(r.commission);
  const paidWith = String(r.paid_with ?? r.payment_method ?? "cash");
  return {
    number: driverReceiptNo(r.id),
    kind: "driver" as const,
    ...trip(r),
    lines: fareLines(r),
    fare,
    commission,
    earning: money(fare - commission),
    collect_cash: paidWith !== "wallet",
    rider_first_name: r.rider_first_name ?? null,
  };
}
