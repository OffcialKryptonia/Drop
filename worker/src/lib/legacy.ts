import type { Context } from "hono";
import type { AppEnv } from "../env";

/**
 * Helpers that keep responses byte-compatible with the legacy Laravel API, because the
 * shipped Flutter apps parse these exact shapes.
 */

/** Exact strings the apps may display (copied from the legacy language files). */
export const MESSAGES = {
  authFailed: "These credentials do not match our records.",
  accountBanned: "Your account is banned. Please contact system administrator.",
  userNotActive: "User is not active. Please contact system administrator.",
  userNotFound: "User not found",
  unauthenticated: "Unauthenticated",
  logout: "Logout successfully",
  validation: "The given data was invalid.",
  riderSaved: "Passenger has been saved successfully",
  driverSaved: "Driver has been save successfully",
} as const;

/** Laravel serializes timestamps as ISO-8601 with microseconds, e.g. 2026-11-03T11:50:11.000000Z. */
export function laravelTime(value: Date | string | null | undefined): string | null {
  if (value === null || value === undefined) return null;
  const d = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(d.getTime())) return null;
  return d.toISOString().replace(/\.(\d{3})Z$/, ".$1000Z");
}

/** Legacy tinyint flags: the apps expect 0/1, not true/false. */
export const flag = (value: unknown): number => (value ? 1 : 0);

/** The legacy columns were text, and the apps declare latitude/longitude as String. */
export const coordText = (value: unknown): string | null =>
  value === null || value === undefined ? null : String(value);

/** Postgres numeric comes back as a string; the legacy API returned JSON numbers. */
export const num = (value: unknown): number | null =>
  value === null || value === undefined ? null : Number(value);

/** 401 in the exact legacy shape; the apps log the user out on any 401. */
export function unauthenticated(c: Context<AppEnv>) {
  return c.json({ error: "unauthenticated", message: MESSAGES.unauthenticated }, 401);
}

/** Laravel-style validation failure: the apps show body.message, which is the first error. */
export function validationFailed(c: Context<AppEnv>, errors: Record<string, string[]>) {
  const first = Object.values(errors)[0]?.[0] ?? MESSAGES.validation;
  return c.json({ message: first, errors }, 422);
}

/** Reads a JSON or form-encoded request body (the legacy API accepted both). */
export async function readBody(c: Context<AppEnv>): Promise<Record<string, unknown>> {
  const type = c.req.header("content-type") ?? "";
  try {
    if (type.includes("application/json")) {
      const body = await c.req.json();
      return body && typeof body === "object" && !Array.isArray(body) ? body : {};
    }
    if (type.includes("form")) {
      const form = await c.req.parseBody();
      return Object.fromEntries(Object.entries(form));
    }
  } catch {
    // fall through to an empty body; validation will report the missing fields
  }
  return {};
}
