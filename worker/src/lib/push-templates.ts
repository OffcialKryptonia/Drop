import { currencyInfo } from "./currency";

/**
 * Push template building blocks that need no database: the variables a template may use, the built-in event
 * catalogue (key, audience, default text), and the validator/renderer.
 *
 * Safety model: a template is plain text with {{name}} placeholders. Only names in VARIABLES are accepted, values are
 * substituted in a single pass (a value containing "{{otp}}" is NOT expanded again), control characters are removed
 * and lengths are capped. Nothing is ever evaluated, so a template cannot run code.
 */

export type VariableDef = { label: string; sample: string; max: number; sensitive?: boolean };

export const VARIABLES: Record<string, VariableDef> = {
  passenger_name: { label: "Passenger's first name", sample: "Amina", max: 40 },
  driver_name: { label: "Driver's first name", sample: "Tunde", max: 40 },
  ride_id: { label: "Ride number", sample: "1042", max: 20 },
  pickup_location: { label: "Pickup address", sample: "Wuse Zone 4, Abuja", max: 80 },
  destination: { label: "Destination address", sample: "Maitama, Abuja", max: 80 },
  airport_name: { label: "Airport name", sample: "Sample Airport", max: 80 },
  airport_code: { label: "Airport code", sample: "XXX", max: 4 },
  terminal: { label: "Terminal", sample: "Terminal 1", max: 40 },
  eta: { label: "Estimated arrival", sample: "5 min", max: 20 },
  fare: { label: "Ride fare", sample: "₦2,500", max: 20 },
  amount: { label: "Amount of money in the message", sample: "₦1,000", max: 20 },
  wallet_balance: { label: "Wallet balance (hidden in the log)", sample: "₦12,400", max: 20, sensitive: true },
  otp: { label: "Pickup code (hidden in the log, never retried)", sample: "4821", max: 8, sensitive: true },
  reason: { label: "Short reason or detail", sample: "was added to your wallet.", max: 100 },
  note: { label: "Note from DROP", sample: "Please send a clearer photo.", max: 160 },
  caller_name: { label: "Name of the person calling", sample: "Amina", max: 40 },
  sender: { label: "Who sent a message", sample: "Your driver", max: 30 },
  document_name: { label: "Document name", sample: "Driver's licence", max: 80 },
  extra_name: { label: "Extra charge name", sample: "Waiting time", max: 60 },
};

/** Own-property check: names like "constructor" or "__proto__" must never count as variables. */
export const isVar = (name: string) => Object.prototype.hasOwnProperty.call(VARIABLES, name);

export const CATEGORIES: Record<string, string> = {
  account: "Welcome and account",
  ride: "Ride updates",
  booking: "Ride requests",
  airport: "Airport transfers",
  bidding: "Fare bidding",
  payment: "Payments and extra charges",
  wallet: "Wallet",
  reminder: "Reminders",
  communication: "Chat and calls",
  promotion: "Promotions and referrals",
  support: "Support",
  safety: "Safety",
  driver_account: "Driver application and account",
  documents: "Documents",
  earnings: "Earnings and payouts",
};

export type EventDef = {
  key: string; name: string; audience: "passenger" | "driver" | "all"; category: string;
  title: string; body: string;
  /** Is some event in the Worker sending this today? Unconnected templates are kept ready but nothing fires them. */
  wired: boolean;
  /** Newly connected by Phase 4: seeded switched off, so merging changes nothing until an admin turns it on. */
  fresh?: boolean;
  note?: string;
};

const E = (key: string, name: string, audience: EventDef["audience"], category: string, title: string, body: string, wired = true, extra: Partial<EventDef> = {}): EventDef =>
  ({ key, name, audience, category, title, body, wired, ...extra });

const NOT_YET = "Not connected yet: DROP has no event that sends this today.";

export const EVENTS: EventDef[] = [
  // ---- Passenger ----
  E("passenger.welcome", "Welcome", "passenger", "account", "Welcome to DROP", "Hi {{passenger_name}}, your account is ready. Book your first ride.", false, { note: "A new account has no phone registered for push yet, so there is nothing to send to at sign-up." }),
  E("passenger.ride_requested", "Ride request received", "passenger", "booking", "Ride requested", "We are finding a driver for your trip to {{destination}}.", true, { fresh: true }),
  E("passenger.driver_assigned", "Driver assigned", "passenger", "ride", "Driver on the way", "A driver accepted your ride and is heading to you."),
  E("passenger.driver_approaching", "Driver approaching", "passenger", "ride", "Your driver is nearly there", "{{driver_name}} is about {{eta}} away.", false, { note: NOT_YET }),
  E("passenger.driver_arrived", "Driver arrived", "passenger", "ride", "Your driver has arrived", "Your driver is at the pickup point."),
  E("passenger.pickup_otp", "Pickup code", "passenger", "ride", "Your pickup code is ready", "Open DROP to see the code to give your driver.", false, { note: "Not connected: the pickup code is stored hashed and shown in the app. Sending it by push would put it on a locked screen, so this needs a decision first." }),
  E("passenger.ride_started", "Ride started", "passenger", "ride", "Trip started", "Enjoy your ride."),
  E("passenger.stop_completed", "Stop completed", "passenger", "ride", "Stop completed", "Your driver finished a stop and is heading to the next one.", true, { fresh: true }),
  E("passenger.ride_completed", "Ride completed", "passenger", "ride", "Trip completed", "Fare {{fare}}. Thanks for riding with DROP."),
  E("passenger.ride_cancelled_by_driver", "Ride cancelled by driver", "passenger", "ride", "Driver cancelled", "Your driver cancelled. We are finding you another driver."),
  E("passenger.ride_cancelled_by_admin", "Ride cancelled by DROP Support", "passenger", "ride", "Ride cancelled by Drop Support", "Drop Support cancelled the ride booked on your behalf."),
  E("passenger.ride_booked_by_support", "Ride booked by DROP Support", "passenger", "booking", "Ride booked by Drop Support", "Drop Support has placed a ride request on your behalf."),
  E("passenger.airport_drop_confirmed", "Airport Drop booked", "passenger", "airport", "Airport Drop requested", "We are finding a driver to take you to {{airport_name}}.", true, { fresh: true }),
  E("passenger.airport_pickup_confirmed", "Airport Pickup booked", "passenger", "airport", "Airport Pickup requested", "We are finding a driver to meet you at {{airport_name}} {{terminal}}.", true, { fresh: true }),
  E("passenger.airport_pickup_reminder", "Airport Pickup reminder", "passenger", "airport", "Your airport pickup is coming up", "Your driver will meet you at {{airport_name}} {{terminal}}.", false, { note: NOT_YET + " Scheduled airport bookings do not exist yet." }),
  E("passenger.airport_drop_reminder", "Airport Drop reminder", "passenger", "airport", "Your airport ride is coming up", "Your ride to {{airport_name}} is almost due.", false, { note: NOT_YET + " Scheduled airport bookings do not exist yet." }),
  E("passenger.scheduled_reminder", "Scheduled ride reminder", "passenger", "reminder", "Your ride is coming up", "Your scheduled ride to {{destination}} is almost due.", false, { note: NOT_YET + " Scheduled rides do not exist yet." }),
  E("passenger.extra_charge_requested", "Extra charge requested", "passenger", "payment", "Extra charge from your driver", "{{extra_name}} · {{amount}}. Open DROP to approve or decline."),
  E("passenger.extra_charge_refunded", "Extra charge refunded", "passenger", "payment", "Extra charge refunded", "{{extra_name}} · {{amount}}"),
  E("passenger.extra_charge_cancelled", "Extra charge cancelled", "passenger", "payment", "Extra charge cancelled", "{{extra_name}} · {{amount}}"),
  E("passenger.payment_confirmed", "Payment confirmation", "passenger", "payment", "Payment received", "We received {{amount}}. Thank you.", false, { note: NOT_YET }),
  E("passenger.wallet_credited", "Wallet credited", "passenger", "wallet", "Wallet credited", "{{amount}} {{reason}}"),
  E("passenger.promotion", "Promotion", "passenger", "promotion", "A gift from DROP", "{{note}}", false, { note: "Not connected: promotions are not built yet." }),
  E("passenger.referral", "Referral event", "passenger", "promotion", "Your referral joined DROP", "Thanks for spreading the word.", false, { note: "Not connected: referrals are not built yet." }),
  E("passenger.support_update", "Support update", "passenger", "support", "Update from DROP Support", "{{note}}", true, { fresh: true }),
  E("driver.support_update", "Support update", "driver", "support", "Update from DROP Support", "{{note}}", true, { fresh: true }),
  E("passenger.safety_alert", "Safety alert", "passenger", "safety", "Safety alert", "{{note}}", false, { note: NOT_YET }),
  E("passenger.bid_driver_accepted", "Bid: a driver accepted", "passenger", "bidding", "A driver accepted your offer", "{{amount}}. Open DROP to choose your driver."),
  E("passenger.bid_counteroffer", "Bid: a driver counteroffered", "passenger", "bidding", "A driver sent a counteroffer", "{{amount}}. Open DROP to answer."),
  E("passenger.bid_expired", "Bid expired", "passenger", "bidding", "Your bid expired", "No driver was chosen in time. You can try again or book a standard ride."),
  E("passenger.bid_driver_withdrew", "Bid: a driver pulled out", "passenger", "bidding", "A driver pulled out", "Choose another driver or try again."),

  // ---- Driver ----
  E("driver.new_ride_request", "New ride request", "driver", "booking", "New ride request", "{{fare}} · {{pickup_location}}"),
  E("driver.ride_assigned", "Ride assigned by dispatch", "driver", "booking", "A ride was assigned to you", "Pickup: {{pickup_location}}.", true, { fresh: true }),
  E("driver.airport_booking_assigned", "Airport booking accepted", "driver", "airport", "Airport booking confirmed", "{{airport_name}} {{terminal}}. Pickup: {{pickup_location}}.", true, { fresh: true }),
  E("driver.ride_cancelled_by_passenger", "Ride cancelled by passenger", "driver", "ride", "Ride cancelled", "The passenger cancelled this ride."),
  E("driver.ride_cancelled_by_admin", "Ride cancelled by DROP Support", "driver", "ride", "Ride cancelled by Drop Support", "Drop Support cancelled this booking. You can accept other requests."),
  E("driver.passenger_arrived", "Passenger at pickup", "driver", "ride", "Your passenger is at the pickup point", "{{passenger_name}} is waiting.", false, { note: NOT_YET }),
  E("driver.pickup_authorised", "Pickup authorised by DROP", "driver", "ride", "Pickup authorised", "DROP authorised the trip. You can start it now."),
  E("driver.stop_update", "Multi-stop update", "driver", "ride", "Stops updated", "The stops on your trip changed.", false, { note: NOT_YET }),
  E("driver.ride_completed", "Ride completed", "driver", "ride", "Trip completed", "Well done. {{amount}} earned.", false, { note: NOT_YET }),
  E("driver.earnings", "Earnings summary", "driver", "earnings", "Your earnings", "{{amount}} {{reason}}", false, { note: NOT_YET }),
  E("driver.payout_update", "Payout update", "driver", "earnings", "Payout update", "Your payout of {{amount}} {{reason}}", false, { note: NOT_YET + " Payouts do not send a push today." }),
  E("driver.wallet_credited", "Wallet credited", "driver", "wallet", "Wallet credited", "{{amount}} {{reason}}"),
  E("driver.application_approved", "Application approved", "driver", "driver_account", "DROP driver application", "You are approved. Switch to driver mode from the menu to start earning."),
  E("driver.application_rejected", "Application not approved", "driver", "driver_account", "DROP driver application", "Your application was not approved. {{note}}"),
  E("driver.application_needs_changes", "Application needs changes", "driver", "driver_account", "DROP driver application", "Your application needs changes. {{note}}"),
  E("driver.account_suspended", "Account suspended", "driver", "driver_account", "DROP driver application", "Driver mode is suspended. Please contact DROP support."),
  E("driver.account_reinstated", "Account reinstated", "driver", "driver_account", "DROP driver application", "Driver mode is back on."),
  E("driver.account_warning", "Account warning", "driver", "driver_account", "Account warning", "{{note}}", false, { note: NOT_YET }),
  E("driver.documents_requested", "Documents requested", "driver", "documents", "DROP needs a document from you", "Please upload: {{document_name}}. {{note}}"),
  E("driver.document_approved", "Document approved", "driver", "documents", "Document approved", "Your {{document_name}} was approved.", false, { note: NOT_YET }),
  E("driver.document_rejected", "Document rejected", "driver", "documents", "Document rejected", "Your {{document_name}} was not accepted. {{note}}", false, { note: NOT_YET }),
  E("driver.document_expiring", "Document expiring", "driver", "documents", "A document is expiring", "Your {{document_name}} expires soon. Please upload a new one.", false, { note: NOT_YET + " No job checks document expiry dates yet." }),
  E("driver.scheduled_reminder", "Scheduled booking reminder", "driver", "reminder", "Your booking is coming up", "Pickup: {{pickup_location}}.", false, { note: NOT_YET + " Scheduled rides do not exist yet." }),
  E("driver.extra_charge_paid", "Extra charge paid", "driver", "payment", "Extra charge paid", "{{amount}} was added to your wallet."),
  E("driver.extra_charge_cash_due", "Collect cash for extra charge", "driver", "payment", "Collect cash for the extra charge", "The passenger will pay {{amount}} in cash."),
  E("driver.extra_charge_declined", "Extra charge declined", "driver", "payment", "Extra charge declined", "The passenger declined the {{extra_name}} of {{amount}}."),
  E("driver.new_bid", "New passenger bid", "driver", "bidding", "New passenger bid", "{{amount}} · {{pickup_location}}"),
  E("driver.bid_raised", "Passenger raised bid", "driver", "bidding", "Passenger raised their offer", "{{amount}}. Take another look."),
  E("driver.bid_revised", "Passenger revised bid", "driver", "bidding", "Passenger revised their offer", "{{amount}}. Open DROP to answer."),
  E("driver.bid_counter_accepted", "Counteroffer accepted", "driver", "bidding", "Passenger accepted your counteroffer", "{{amount}}. They may pick you next."),
  E("driver.bid_counter_declined", "Counteroffer declined", "driver", "bidding", "Counteroffer declined", "The passenger declined your counteroffer."),
  E("driver.bid_cancelled", "Bid cancelled", "driver", "bidding", "Bid cancelled", "The passenger cancelled this bid."),
  E("driver.bid_selected", "You were chosen", "driver", "bidding", "You were chosen", "{{amount}} fare confirmed. Head to the pickup point."),
  E("driver.bid_selection_lost", "Passenger chose another driver", "driver", "bidding", "Passenger chose another driver", "That bid is no longer available."),
  E("driver.bid_response_expired", "Bid response expired", "driver", "bidding", "Your bid response expired", "The passenger did not answer in time."),

  // ---- Both ----
  E("ride.chat_message", "New chat message", "all", "communication", "New message", "{{sender}} sent you a message. Open DROP to read it."),
  E("ride.voice_message", "New voice message", "all", "communication", "New voice message", "{{sender}} sent you a message. Open DROP to read it."),
  E("ride.call_incoming", "Incoming call", "all", "communication", "Incoming call", "{{caller_name}} is calling you on Drop."),
  E("ride.call_missed", "Missed call", "all", "communication", "Missed call", "{{caller_name}} tried to call you."),
];

export const EVENT_BY_KEY = new Map(EVENTS.map((e) => [e.key, e]));

// ---------- placeholders ----------

const PLACEHOLDER = /\{\{\s*([a-z_]+)\s*\}\}/g;

/** The valid placeholder names in a text, and whether the text has braces that look like a placeholder but are not valid. */
export function placeholders(text: string): { names: string[]; malformed: boolean } {
  const names: string[] = [];
  for (const m of text.matchAll(PLACEHOLDER)) if (!names.includes(m[1])) names.push(m[1]);
  const stripped = text.replace(PLACEHOLDER, "");
  return { names, malformed: stripped.includes("{{") || stripped.includes("}}") };
}

const clean = (v: unknown, max: number) =>
  String(v ?? "").replace(/[\u0000-\u001f\u007f\u2028\u2029]/g, " ").replace(/\s+/g, " ").trim().slice(0, max);

/** Single-pass substitution. Unknown names render as empty (they cannot be saved, but old rows must never throw). */
export function renderText(text: string, values: Record<string, unknown>, opts: { mask?: boolean; encode?: boolean } = {}): string {
  const out = text.replace(PLACEHOLDER, (_m, name: string) => {
    if (!isVar(name)) return "";
    const def = VARIABLES[name];
    if (opts.mask && def.sensitive) return "••••";
    const v = clean(Object.prototype.hasOwnProperty.call(values, name) ? values[name] : "", def.max);
    return opts.encode ? encodeURIComponent(v) : v;
  });
  return opts.encode ? out : out.replace(/\s{2,}/g, " ").replace(/\s*[·,]\s*$/, "").replace(/^\s*[·,]\s*/, "").trim();
}

export const sampleValues = (): Record<string, string> => Object.fromEntries(Object.entries(VARIABLES).map(([k, v]) => [k, v.sample]));

export const usesSensitive = (...texts: (string | null | undefined)[]) =>
  texts.some((t) => t && placeholders(t).names.some((n) => isVar(n) && VARIABLES[n].sensitive));

// ---------- deep links ----------

/**
 * A deep link is either drop://path (opened inside the app) or an https link to a host an admin listed in
 * Settings. Anything else (javascript:, data:, http:, other hosts, links with credentials) is refused.
 */
export function safeDeepLink(link: string, allowedHosts: string[]): boolean {
  if (/^drop:\/\/[a-z0-9][a-z0-9_\-/.]*(\?[a-z0-9_\-=&%.]*)?$/i.test(link)) return true;
  try {
    const u = new URL(link);
    return u.protocol === "https:" && !u.username && !u.password && !u.port && allowedHosts.includes(u.hostname.toLowerCase());
  } catch { return false; }
}

// ---------- validation ----------

export type TemplateInput = {
  key?: string; name: string; category: string; audience: string; title: string; body: string;
  image_url?: string | null; deep_link?: string | null; action_label?: string | null;
};

/** Returns field -> messages. Empty means valid. `variables` is derived here, never taken from the client. */
export function validateTemplate(t: TemplateInput, ctx: { allowedLinkHosts: string[]; checkKey?: boolean }): { errors: Record<string, string[]>; variables: string[] } {
  const errors: Record<string, string[]> = {};
  const add = (f: string, m: string) => (errors[f] ??= []).push(m);
  if (ctx.checkKey !== false) {
    if (!t.key || !/^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$/.test(t.key) || t.key.length > 80) add("key", "Use lowercase words joined by dots, like passenger.driver_assigned.");
  }
  const name = (t.name ?? "").trim();
  if (name.length < 2 || name.length > 120) add("name", "Enter a name (2 to 120 characters).");
  if (!CATEGORIES[t.category]) add("category", "Choose a category.");
  if (!["passenger", "driver", "all"].includes(t.audience)) add("audience", "Choose who receives it.");
  const title = (t.title ?? "").trim(), body = (t.body ?? "").trim();
  if (!title || title.length > 80) add("title", "Enter a title (up to 80 characters).");
  if (!body || body.length > 300) add("body", "Enter the message (up to 300 characters).");
  const vars: string[] = [];
  const checkText = (field: string, text: string, allowSensitive = true) => {
    if (!text) return;
    const p = placeholders(text);
    if (p.malformed) add(field, "A placeholder is not written correctly. Use {{name}} with letters and underscores only.");
    const unknown = p.names.filter((n) => !isVar(n));
    if (unknown.length) add(field, `Unknown placeholder: ${unknown.map((n) => `{{${n}}}`).join(", ")}.`);
    if (!allowSensitive && p.names.some((n) => isVar(n) && VARIABLES[n].sensitive)) add(field, "A link cannot contain the pickup code or wallet balance.");
    for (const n of p.names) if (isVar(n) && !vars.includes(n)) vars.push(n);
  };
  checkText("title", title); checkText("body", body);
  if (t.image_url) {
    if (!/^https:\/\/[^\s{}]+$/.test(t.image_url) || t.image_url.length > 500) add("image_url", "The image must be a plain https link.");
  }
  if (t.deep_link) {
    checkText("deep_link", t.deep_link, false);
    const probe = renderText(t.deep_link, Object.fromEntries(Object.keys(VARIABLES).map((k) => [k, "x"])), { encode: true });
    if (!errors.deep_link && !safeDeepLink(probe, ctx.allowedLinkHosts)) add("deep_link", "Use a drop:// link, or an https link to a host listed in Settings.");
  }
  if (t.action_label != null && t.action_label !== "" && (t.action_label.trim().length < 1 || t.action_label.length > 30)) add("action_label", "The action label can be up to 30 characters.");
  return { errors, variables: vars };
}

export const money = (amount: unknown, currency: unknown) => {
  const i = currencyInfo(String(currency ?? "NGN").trim() || "NGN");
  return `${i.symbol}${Number(amount).toLocaleString("en-NG", { maximumFractionDigits: 2 })}`;
};
