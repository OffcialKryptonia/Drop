export type FareRule = {
  base_fare: number | string | null;
  minimum_fare: number | string | null;
  minimum_distance: number | string | null;
  per_distance: number | string | null;
  per_minute_drive: number | string | null;
};

const n = (v: unknown) => {
  const x = Number(v);
  return Number.isFinite(x) ? x : 0;
};
const money = (v: number) => Math.round(v * 100) / 100;

export type FareBreakdown = {
  base_fare: number;
  distance_charge: number;
  time_charge: number;
  options_total: number;
  minimum_fare_applied: boolean;
  total: number;
};

/**
 * Fare for a ride type. `distance` is in the region's unit (km or mile), the same unit the admin used for the prices.
 * base fare covers the first `minimum_distance`; distance beyond it is charged per unit; time is charged per minute;
 * the trip price is never below the minimum fare; chosen extras are added on top.
 */
export function computeFare(rule: FareRule, distance: number, durationMinutes: number, optionsTotal = 0): FareBreakdown {
  const base = n(rule.base_fare);
  const extra = Math.max(0, distance - n(rule.minimum_distance));
  const distanceCharge = extra * n(rule.per_distance);
  const timeCharge = Math.max(0, durationMinutes) * n(rule.per_minute_drive);
  const trip = base + distanceCharge + timeCharge;
  const minimum = n(rule.minimum_fare);
  const applied = trip < minimum;
  const total = (applied ? minimum : trip) + optionsTotal;
  return {
    base_fare: money(base),
    distance_charge: money(distanceCharge),
    time_charge: money(timeCharge),
    options_total: money(optionsTotal),
    minimum_fare_applied: applied,
    total: money(total),
  };
}
