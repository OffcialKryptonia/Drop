/** Shared, pure helpers for the analytics and finance reports: periods, rates, money grouping, CSV. Tested without a database. */

export const DEFAULT_TZ = "Africa/Lagos";
export const MAX_PERIOD_DAYS = 366;

export type Period = { from: string; to: string; tz: string; days: number; defaulted: boolean };

const DAY = /^\d{4}-\d{2}-\d{2}$/;
const validDay = (s: string) => DAY.test(s) && !Number.isNaN(Date.parse(s + "T00:00:00Z")) && new Date(s + "T00:00:00Z").toISOString().slice(0, 10) === s;
export function validTz(tz: unknown): string {
  try { if (typeof tz === "string" && tz) { new Intl.DateTimeFormat("en", { timeZone: tz }); return tz; } } catch { /* fall through */ }
  return DEFAULT_TZ;
}
const dayInTz = (ms: number, tz: string) => new Intl.DateTimeFormat("en-CA", { timeZone: tz, year: "numeric", month: "2-digit", day: "2-digit" }).format(ms);

/**
 * A reporting period is whole calendar days in one time zone, both ends included ("2026-11-01" to "2026-11-30" is all of November).
 * Missing dates default to the last 30 days including today. Returns an error message instead of guessing when dates are invalid.
 */
export function parsePeriod(q: { from?: string | null; to?: string | null; tz?: string | null }, now = Date.now()): Period | { error: string } {
  const tz = validTz(q.tz);
  const today = dayInTz(now, tz);
  const defaulted = !q.from && !q.to;
  const to = q.to || today;
  const from = q.from || dayInTz(Date.parse(to + "T12:00:00Z") - 29 * 86400_000, "UTC");
  if (!validDay(from) || !validDay(to)) return { error: "Dates must look like 2026-11-30." };
  if (from > to) return { error: "The start date is after the end date." };
  const days = Math.round((Date.parse(to + "T00:00:00Z") - Date.parse(from + "T00:00:00Z")) / 86400_000) + 1;
  if (days > MAX_PERIOD_DAYS) return { error: `A period can be at most ${MAX_PERIOD_DAYS} days.` };
  return { from, to, tz, days, defaulted };
}

/** A percentage with two decimals, or null when there is nothing to divide by. Null means "no data", never 0%. */
export const rate = (n: number, d: number): number | null => (d > 0 ? Math.round((n / d) * 10000) / 100 : null);
export const avg = (sum: number, n: number): number | null => (n > 0 ? Math.round((sum / n) * 100) / 100 : null);
export const round2 = (v: unknown) => Math.round(Number(v ?? 0) * 100) / 100;

export type Money = { currency: string; amount: number };
/** Rows of {currency, amount} into a stable list; amounts of different currencies are never added together. */
export function moneyList(rows: { currency?: string | null; amount?: unknown }[]): Money[] {
  const m = new Map<string, number>();
  for (const r of rows) {
    const cur = String(r.currency ?? "NGN").trim() || "NGN";
    m.set(cur, (m.get(cur) ?? 0) + Number(r.amount ?? 0));
  }
  return [...m.entries()].sort(([a], [b]) => a.localeCompare(b)).map(([currency, amount]) => ({ currency, amount: round2(amount) }));
}

export const freqBucket = (n: number) => (n <= 1 ? "1" : n <= 3 ? "2-3" : n <= 9 ? "4-9" : "10+");
export const FREQ_BUCKETS = ["1", "2-3", "4-9", "10+"];

/** A retention cohort is only reported once every member has had the whole follow-up window to come back. */
export function cohortMature(cohortEndDay: string, windowDays: number, today: string): boolean {
  return Date.parse(cohortEndDay + "T00:00:00Z") + (windowDays + 1) * 86400_000 <= Date.parse(today + "T00:00:00Z");
}

/** Seconds online inside [from, to), clipping each session to the window. An open session counts up to "now". */
export function onlineSeconds(sessions: { started_at: string | number; ended_at: string | number | null }[], from: number, to: number, now: number): number {
  let total = 0;
  for (const s of sessions) {
    const a = Math.max(new Date(s.started_at).getTime(), from);
    const b = Math.min(s.ended_at == null ? now : new Date(s.ended_at).getTime(), to, now);
    if (b > a) total += (b - a) / 1000;
  }
  return Math.round(total);
}

/** CSV that is safe to open in a spreadsheet: quotes are doubled and a leading = + - @ tab or CR is neutralised with an apostrophe. */
export function csvCell(v: unknown): string {
  if (v === null || v === undefined) return "";
  let s = v instanceof Date ? v.toISOString() : typeof v === "object" ? JSON.stringify(v) : String(v);
  if (/^[=+\-@\t\r]/.test(s) && !(typeof v === "number" && Number.isFinite(v))) s = "'" + s;
  return /[",\n\r]/.test(s) ? '"' + s.replace(/"/g, '""') + '"' : s;
}
export function toCsv(columns: { key: string; label: string }[], rows: Record<string, unknown>[]): string {
  const lines = [columns.map((c) => csvCell(c.label)).join(",")];
  for (const r of rows) lines.push(columns.map((c) => csvCell(r[c.key])).join(","));
  return "﻿" + lines.join("\r\n") + "\r\n";
}
