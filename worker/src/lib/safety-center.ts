/** Rules for safety incidents. Pure, so the state machine and the privacy masking are tested without a database. */

export const INCIDENT_STATUSES = ["open", "acknowledged", "investigating", "escalated", "resolved", "closed"] as const;
export type IncidentStatus = (typeof INCIDENT_STATUSES)[number];

/** "open" is the stored value of the New state: existing rows and the apps already use it. */
export const STATUS_LABEL: Record<IncidentStatus, string> = {
  open: "New", acknowledged: "Acknowledged", investigating: "Investigating", escalated: "Escalated", resolved: "Resolved", closed: "Closed",
};

/** Where an incident may go next. Closed is final so the record cannot be quietly reopened. */
export const TRANSITIONS: Record<IncidentStatus, IncidentStatus[]> = {
  open: ["acknowledged", "investigating", "escalated", "resolved"],
  acknowledged: ["investigating", "escalated", "resolved"],
  investigating: ["escalated", "resolved"],
  escalated: ["investigating", "resolved"],
  resolved: ["investigating", "closed"],
  closed: [],
};

export const CATEGORIES = ["sos", "accident", "harassment", "unsafe_driving", "route_deviation", "vehicle_issue", "theft", "medical", "other"] as const;
export const SEVERITIES = ["low", "medium", "high", "critical"] as const;

export const isStatus = (v: unknown): v is IncidentStatus => (INCIDENT_STATUSES as readonly string[]).includes(String(v));
export const canTransition = (from: string, to: string) => isStatus(from) && isStatus(to) && TRANSITIONS[from].includes(to);
/** Resolving and escalating must say why, so the history explains itself. */
export const needsNote = (to: string) => to === "resolved" || to === "escalated";
export const isActive = (status: string) => status !== "resolved" && status !== "closed";

/** "Ada Obi" becomes "Ada O.": enough to tell people apart, not enough to identify them. */
export function maskName(name: string | null | undefined): string {
  const parts = String(name ?? "").trim().split(/\s+/).filter(Boolean);
  if (!parts.length) return "Unknown";
  if (parts.length === 1) return parts[0];
  return `${parts[0]} ${parts[parts.length - 1][0].toUpperCase()}.`;
}

/** About one kilometre: shows the area, not the door. */
export const approxCoord = (v: unknown): number | null => (v == null || v === "" || !Number.isFinite(Number(v)) ? null : Math.round(Number(v) * 100) / 100);

type Row = Record<string, unknown>;
const iso = (v: unknown) => (v ? new Date(v as string).toISOString() : null);
const num = (v: unknown) => (v == null ? null : Number(v));

/**
 * What an admin sees of an incident. Without the "pii" permission: masked names, an approximate area, no phone numbers, no plate.
 * With it: the full detail, but only through the logged reveal call, never in lists.
 */
export function incidentView(r: Row, o: { pii: boolean; names?: { person?: string | null; other?: string | null; assignee?: string | null; handler?: string | null } }) {
  const ctx = (r.context ?? {}) as { person?: { name?: string }; other_party?: { name?: string } | null; ride?: { id?: number; status?: string } | null };
  const person = o.names?.person ?? ctx.person?.name ?? null;
  const other = o.names?.other ?? ctx.other_party?.name ?? null;
  const hasLoc = r.latitude != null && r.longitude != null;
  return {
    id: Number(r.id), status: r.status as string, status_label: STATUS_LABEL[r.status as IncidentStatus] ?? String(r.status),
    category: r.category as string, severity: r.severity as string, source: r.source as string, role: r.role as string,
    person: { name: o.pii ? person : maskName(person), role: r.role as string },
    other_party: other ? { name: o.pii ? other : maskName(other), role: r.role === "driver" ? "rider" : "driver" } : null,
    ride_request_id: r.ride_request_id == null ? null : Number(r.ride_request_id),
    location: hasLoc ? { approximate: true, lat: approxCoord(r.latitude), lng: approxCoord(r.longitude) } : null,
    message: r.message ?? null,
    assigned_to: r.assigned_to == null ? null : { id: Number(r.assigned_to), name: o.names?.assignee ?? null },
    created_at: iso(r.created_at), updated_at: iso(r.updated_at), closed_at: iso(r.closed_at),
    handled_by: r.handled_by == null ? null : { id: Number(r.handled_by), name: o.names?.handler ?? null },
    age_seconds: Math.max(0, Math.round((Date.now() - new Date(r.created_at as string).getTime()) / 1000)),
  };
}
