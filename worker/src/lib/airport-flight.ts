import type { Client } from "pg";
import type { AirportDirection } from "./airports";

/**
 * Flight / meeting details on an airport booking. Which fields are asked for, and which are required, is an Admin setting
 * per direction. These are details the passenger types in: DROP does not look flights up, track them or confirm them.
 */
export const FLIGHT_FIELDS = ["airline", "flight_number", "arrival_date", "arrival_time", "terminal", "passenger_count", "luggage_count", "contact_phone", "instructions"] as const;
export type FlightField = (typeof FLIGHT_FIELDS)[number];
export type FieldRule = { enabled: boolean; required: boolean };
export type FlightFieldConfig = Record<AirportDirection, Record<FlightField, FieldRule>>;

const r = (enabled: boolean, required = false): FieldRule => ({ enabled, required });
export const DEFAULT_FLIGHT_FIELDS: FlightFieldConfig = {
  pickup: {
    airline: r(true), flight_number: r(true, true), arrival_date: r(true), arrival_time: r(true), terminal: r(true, true),
    passenger_count: r(true), luggage_count: r(true), contact_phone: r(true), instructions: r(true),
  },
  drop: {
    airline: r(false), flight_number: r(true), arrival_date: r(false), arrival_time: r(false), terminal: r(true),
    passenger_count: r(true), luggage_count: r(true), contact_phone: r(false), instructions: r(true),
  },
};

const KEY = "airport_flight_fields";

/** Saved settings layered over the defaults; unknown keys are dropped and a required field is always enabled. */
export function mergeConfig(saved: unknown): FlightFieldConfig {
  const out = JSON.parse(JSON.stringify(DEFAULT_FLIGHT_FIELDS)) as FlightFieldConfig;
  if (!saved || typeof saved !== "object") return out;
  for (const dir of ["drop", "pickup"] as const) {
    const d = (saved as Record<string, unknown>)[dir];
    if (!d || typeof d !== "object") continue;
    for (const f of FLIGHT_FIELDS) {
      const v = (d as Record<string, unknown>)[f];
      if (v && typeof v === "object") {
        const required = (v as FieldRule).required === true;
        out[dir][f] = { enabled: required || (v as FieldRule).enabled === true, required };
      }
    }
  }
  return out;
}

export async function loadFlightConfig(db: Client): Promise<FlightFieldConfig> {
  const row = (await db.query("select value from app.settings where key = $1", [KEY])).rows[0];
  return mergeConfig(row?.value);
}
export async function saveFlightConfig(db: Client, cfg: FlightFieldConfig) {
  await db.query("insert into app.settings (key, value) values ($1, $2::jsonb) on conflict (key) do update set value = excluded.value", [KEY, JSON.stringify(cfg)]);
}

const clean = (v: unknown, max: number) => (typeof v === "string" ? v.replace(/\s+/g, " ").trim().slice(0, max) : typeof v === "number" ? String(v) : "");

export type Flight = Partial<Record<FlightField, string | number>>;
export type FlightResult = { ok: true; flight: Flight } | { ok: false; errors: Record<string, string> };

const LABEL: Record<FlightField, string> = {
  airline: "Airline", flight_number: "Flight number", arrival_date: "Date", arrival_time: "Time", terminal: "Terminal",
  passenger_count: "Passengers", luggage_count: "Luggage", contact_phone: "Contact number", instructions: "Instructions",
};

/** Keeps only enabled fields, enforces required ones and checks each value's shape. Terminal must be one the airport lists, when it lists any. */
export function validateFlight(cfg: FlightFieldConfig, direction: AirportDirection, input: unknown, terminals: unknown): FlightResult {
  const raw = (input && typeof input === "object" ? input : {}) as Record<string, unknown>;
  const rules = cfg[direction];
  const names = Array.isArray(terminals) ? terminals.map((t) => clean((t as { name?: unknown })?.name, 80)).filter(Boolean) : [];
  const flight: Flight = {};
  const errors: Record<string, string> = {};
  for (const f of FLIGHT_FIELDS) {
    const rule = rules[f];
    if (!rule.enabled) continue;
    const v = raw[f];
    const empty = v === undefined || v === null || (typeof v === "string" && !v.trim());
    if (empty) { if (rule.required) errors[f] = `${LABEL[f]} is required.`; continue; }
    switch (f) {
      case "flight_number": {
        const s = clean(v, 12).toUpperCase().replace(/\s+/g, "");
        if (!/^[A-Z0-9]{2,3}\d{1,4}[A-Z]?$/.test(s)) errors[f] = "Enter a flight number like KQ 530.";
        else flight[f] = s;
        break;
      }
      case "arrival_date": {
        const s = clean(v, 10);
        const ok = /^\d{4}-\d{2}-\d{2}$/.test(s) && !Number.isNaN(Date.parse(s + "T00:00:00Z")) && new Date(s + "T00:00:00Z").toISOString().startsWith(s);
        if (!ok) errors[f] = "Enter the date as YYYY-MM-DD."; else flight[f] = s;
        break;
      }
      case "arrival_time": {
        const s = clean(v, 5);
        if (!/^([01]\d|2[0-3]):[0-5]\d$/.test(s)) errors[f] = "Enter the time as HH:MM (24 hour)."; else flight[f] = s;
        break;
      }
      case "terminal": {
        const s = clean(v, 80);
        const hit = names.find((n) => n.toLowerCase() === s.toLowerCase());
        if (names.length && !hit) errors[f] = "Choose one of this airport's terminals.";
        else flight[f] = hit ?? s;
        break;
      }
      case "passenger_count":
      case "luggage_count": {
        const n = Number(v);
        const min = f === "passenger_count" ? 1 : 0;
        if (!Number.isInteger(n) || n < min || n > 20) errors[f] = `${LABEL[f]} must be a whole number from ${min} to 20.`; else flight[f] = n;
        break;
      }
      case "contact_phone": {
        const s = clean(v, 20);
        if (!/^\+?[0-9 ()-]{7,20}$/.test(s)) errors[f] = "Enter a valid phone number."; else flight[f] = s;
        break;
      }
      default: {
        const s = clean(v, f === "instructions" ? 300 : 60);
        if (s) flight[f] = s;
      }
    }
  }
  return Object.keys(errors).length ? { ok: false, errors } : { ok: true, flight };
}

/** What a driver may see: everything except the passenger's phone number, which only ever flows through in-app calls. */
export function driverFlight(flight: unknown): (Flight & { has_contact: boolean }) | null {
  if (!flight || typeof flight !== "object") return null;
  const { contact_phone, ...rest } = flight as Flight;
  return { ...rest, has_contact: Boolean(contact_phone) };
}
