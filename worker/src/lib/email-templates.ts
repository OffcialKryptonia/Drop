import { VARIABLES as PUSH_VARIABLES, type VariableDef } from "./push-templates";

/**
 * Email template building blocks that need no database: the variables a template may use, the built-in event
 * catalogue, the HTML safety check, the renderer and the branded, responsive, dark-mode-aware layout.
 *
 * Safety model:
 *  - A template is a small HTML fragment with {{name}} placeholders. Only names in VARIABLES are accepted.
 *  - Values are substituted in ONE pass (a value containing "{{code}}" is not expanded again) and HTML-escaped.
 *  - The HTML is checked against an allow-list when it is SAVED and again when it is SENT. Anything else is refused,
 *    not cleaned: no scripts, forms, iframes, event handlers, comments, javascript:/data: links, CSS url() or imports.
 *  - Nothing is ever evaluated, so a template cannot run code.
 */

export type EmailVarDef = VariableDef & { url?: boolean };

const pick = (...names: string[]) => Object.fromEntries(names.map((n) => [n, PUSH_VARIABLES[n]]));

export const VARIABLES: Record<string, EmailVarDef> = {
  ...pick("passenger_name", "driver_name", "ride_id", "pickup_location", "destination", "airport_name", "airport_code", "terminal",
    "eta", "fare", "amount", "wallet_balance", "reason", "document_name", "extra_name"),
  note: { ...PUSH_VARIABLES.note, max: 400 },
  recipient_name: { label: "Recipient's first name", sample: "Amina", max: 40 },
  code: { label: "Verification code (hidden in the log, never retried)", sample: "482193", max: 8, sensitive: true },
  secure_link: { label: "Secure link (hidden in the log, never retried)", sample: "https://example.com/secure", max: 500, sensitive: true, url: true },
  action_url: { label: "Button link (https)", sample: "https://example.com/open", max: 500, url: true },
  expires_in: { label: "How long a code lasts", sample: "15 minutes", max: 30 },
  ride_date: { label: "Date and time of the trip", sample: "12 Dec 2026, 14:30", max: 40 },
  scheduled_time: { label: "Scheduled pickup time", sample: "13 Dec 2026, 09:00", max: 40 },
  flight_number: { label: "Flight number", sample: "AB123", max: 12 },
  vehicle: { label: "Vehicle description", sample: "Silver Toyota Corolla", max: 60 },
  plate: { label: "Number plate", sample: "ABC-123XY", max: 16 },
  distance: { label: "Trip distance", sample: "12.4 km", max: 20 },
  duration: { label: "Trip duration", sample: "28 min", max: 20 },
  payment_method: { label: "Payment method", sample: "Wallet", max: 30 },
  reference: { label: "Payment or refund reference", sample: "DRP-48213", max: 40 },
  refund_amount: { label: "Refund amount", sample: "₦2,500", max: 20 },
  period: { label: "Statement period", sample: "1 to 7 Dec 2026", max: 40 },
  trips_count: { label: "Number of trips", sample: "24", max: 8 },
  earnings_total: { label: "Total earnings", sample: "₦86,400", max: 20 },
  payout_amount: { label: "Payout amount", sample: "₦80,000", max: 20 },
  payout_destination: { label: "Payout destination (masked)", sample: "Bank account ending 1234", max: 60 },
  ticket_id: { label: "Support ticket number", sample: "T-2041", max: 20 },
  expiry_date: { label: "Expiry date", sample: "30 Dec 2026", max: 30 },
  event_time: { label: "When it happened", sample: "12 Dec 2026, 14:30", max: 40 },
  device: { label: "Device or browser", sample: "Android phone", max: 60 },
  headline: { label: "Announcement headline", sample: "Planned maintenance", max: 100 },
  message: { label: "Announcement message", sample: "DROP will be briefly unavailable.", max: 600 },
  effective_date: { label: "Date a change takes effect", sample: "1 Jan 2027", max: 30 },
  referral_bonus: { label: "Referral reward", sample: "₦500", max: 20 },
  // Supplied automatically from Admin branding on every email:
  brand_name: { label: "Brand name (from branding)", sample: "DROP", max: 40 },
  support_email: { label: "Support email (from branding)", sample: "support@example.com", max: 80 },
};

export const isVar = (name: string) => Object.prototype.hasOwnProperty.call(VARIABLES, name);
const isUrlVar = (name: string) => isVar(name) && Boolean(VARIABLES[name].url);

export const CATEGORIES: Record<string, string> = {
  account: "Welcome and account",
  verification: "Verification and security",
  ride: "Ride confirmations and updates",
  airport: "Airport transfers",
  payment: "Payments, receipts and refunds",
  wallet: "Wallet",
  promotion: "Referrals",
  support: "Support",
  driver_account: "Driver application and account",
  documents: "Documents",
  earnings: "Earnings and payouts",
  announcement: "Announcements and policy",
};

export const AUDIENCES = ["passenger", "driver", "system"] as const;

// ---------- placeholders ----------

const PLACEHOLDER = /\{\{\s*([a-z_]+)\s*\}\}/g;

export function placeholders(text: string): { names: string[]; malformed: boolean } {
  const names: string[] = [];
  for (const m of text.matchAll(PLACEHOLDER)) if (!names.includes(m[1])) names.push(m[1]);
  const stripped = text.replace(PLACEHOLDER, "");
  return { names, malformed: stripped.includes("{{") || stripped.includes("}}") };
}

export const sampleValues = (): Record<string, string> => Object.fromEntries(Object.entries(VARIABLES).map(([k, v]) => [k, v.sample]));

export const usesSensitive = (...texts: (string | null | undefined)[]) =>
  texts.some((t) => t && placeholders(t).names.some((n) => isVar(n) && VARIABLES[n].sensitive));

const cleanLine = (v: unknown, max: number) => String(v ?? "").replace(/[\u0000-\u001f\u007f\u2028\u2029]/g, " ").replace(/\s+/g, " ").trim().slice(0, max);
const cleanText = (v: unknown, max: number) => String(v ?? "").replace(/[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f\u2028\u2029]/g, " ").trim().slice(0, max);

export const escapeHtml = (s: string) => s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;").replace(/'/g, "&#39;");

/** A link value is accepted only when it is a plain https URL without credentials; anything else becomes empty. */
export function safeUrl(v: unknown): string {
  const s = String(v ?? "").trim();
  if (!s || s.length > 500 || /[\s<>"'`\\]/.test(s)) return "";
  try {
    const u = new URL(s);
    return u.protocol === "https:" && !u.username && !u.password ? u.toString() : "";
  } catch { return ""; }
}

type RenderMode = "html" | "text" | "subject";

function valueOf(name: string, values: Record<string, unknown>, mode: RenderMode, mask: boolean): string {
  if (!isVar(name)) return "";
  const def = VARIABLES[name];
  if (mask && def.sensitive) return mode === "html" ? "&bull;&bull;&bull;&bull;" : "••••";
  const raw = Object.prototype.hasOwnProperty.call(values, name) ? values[name] : "";
  const v = def.url ? safeUrl(raw) : mode === "subject" ? cleanLine(raw, def.max) : cleanText(raw, def.max);
  return mode === "html" ? escapeHtml(v) : v;
}

/** Single-pass substitution (a substituted value is never expanded again). Unknown names render as empty. */
export function renderTemplateText(text: string, values: Record<string, unknown>, mode: RenderMode, mask = false): string {
  const out = text.replace(PLACEHOLDER, (_m, name: string) => valueOf(name, values, mode, mask));
  return mode === "subject" ? out.replace(/\s+/g, " ").trim() : out;
}

// ---------- safe HTML ----------

const TAGS = new Set(["p", "br", "hr", "h1", "h2", "h3", "strong", "b", "em", "i", "u", "small", "span", "div", "a", "ul", "ol", "li",
  "table", "thead", "tbody", "tr", "td", "th", "img", "center"]);
const VOID = new Set(["br", "hr", "img"]);
const ATTRS: Record<string, string[]> = {
  "*": ["style", "class", "align", "title"],
  a: ["href"],
  img: ["src", "alt", "width", "height"],
  table: ["width", "cellpadding", "cellspacing", "border", "role"],
  td: ["width", "colspan", "rowspan", "valign"],
  th: ["width", "colspan", "rowspan", "valign"],
  tr: [],
};
const CLASSES = new Set(["btn", "muted", "code"]);
const STYLE_PROPS = new Set(["color", "background-color", "background", "font-size", "font-weight", "font-style", "text-align", "text-decoration",
  "line-height", "letter-spacing", "padding", "padding-top", "padding-right", "padding-bottom", "padding-left",
  "margin", "margin-top", "margin-right", "margin-bottom", "margin-left", "border", "border-top", "border-right", "border-bottom", "border-left",
  "border-radius", "border-collapse", "width", "max-width", "display", "opacity", "vertical-align"]);

function styleErrors(style: string): string | null {
  for (const decl of style.split(";")) {
    if (!decl.trim()) continue;
    const i = decl.indexOf(":");
    if (i < 1) return "A style is not written correctly.";
    const prop = decl.slice(0, i).trim().toLowerCase(), val = decl.slice(i + 1).trim();
    if (!STYLE_PROPS.has(prop)) return `The style "${prop}" is not allowed.`;
    if (!/^[#a-zA-Z0-9\s.,%()\-+!]*$/.test(val) || /url\s*\(|expression|javascript|@import|var\s*\(|\{\{/i.test(val)) return `The value of style "${prop}" is not allowed.`;
  }
  return null;
}

/**
 * Allow-list check. Returns messages; empty means the HTML is safe to store and send.
 * Links: https, mailto, tel, or a single url placeholder such as {{action_url}}. Images: https only.
 */
export function checkHtml(html: string): string[] {
  const errors: string[] = [];
  const add = (m: string) => { if (!errors.includes(m)) errors.push(m); };
  if (/<!--|<!\[|<\?|<!doctype/i.test(html)) add("Comments, doctype and processing instructions are not allowed.");
  const stack: string[] = [];
  let last = 0;
  const TAG = /<(\/?)([a-zA-Z][a-zA-Z0-9]*)((?:[^>"']|"[^"]*"|'[^']*')*)>/g;
  for (const m of html.matchAll(TAG)) {
    const between = html.slice(last, m.index);
    if (between.includes("<")) add("A stray < character. Write &lt; for a literal less-than sign.");
    last = (m.index ?? 0) + m[0].length;
    const closing = m[1] === "/", tag = m[2].toLowerCase(), rest = m[3];
    if (!TAGS.has(tag)) { add(`The <${tag}> tag is not allowed.`); continue; }
    if (closing) {
      if (VOID.has(tag)) { add(`</${tag}> is not valid.`); continue; }
      if (stack[stack.length - 1] !== tag) add(`The </${tag}> tag does not match an open tag.`); else stack.pop();
      continue;
    }
    const selfClosed = /\/\s*$/.test(rest);
    const attrText = selfClosed ? rest.replace(/\/\s*$/, "") : rest;
    let consumed = "";
    const ATTR = /\s+([a-zA-Z_:][-a-zA-Z0-9_:.]*)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'=<>`]+)))?/g;
    for (const a of attrText.matchAll(ATTR)) {
      consumed += a[0];
      const name = a[1].toLowerCase(), value = a[2] ?? a[3] ?? a[4] ?? "";
      if (name.startsWith("on")) { add("Event handlers such as onclick are not allowed."); continue; }
      if (!(ATTRS["*"].includes(name) || (ATTRS[tag] ?? []).includes(name))) { add(`The "${name}" attribute is not allowed on <${tag}>.`); continue; }
      if (name === "style") { const e = styleErrors(value); if (e) add(e); }
      else if (name === "class") { if (value.split(/\s+/).filter(Boolean).some((c) => !CLASSES.has(c))) add(`Classes other than ${[...CLASSES].join(", ")} are not allowed.`); }
      else if (name === "href") {
        const v = value.trim();
        const ph = v.match(/^\{\{\s*([a-z_]+)\s*\}\}$/);
        if (ph) { if (!isUrlVar(ph[1])) add("A link can only use a link placeholder such as {{action_url}}."); }
        else if (!/^(https:\/\/[^\s{}"'<>]+|mailto:[^\s{}"'<>]+|tel:[+0-9()\-\s]+)$/i.test(v)) add("Links must start with https://, mailto: or tel:, or be {{action_url}}.");
      } else if (name === "src") {
        if (!/^https:\/\/[^\s{}"'<>]+$/i.test(value.trim())) add("Images must use a plain https:// address.");
      } else if (/\{\{/.test(value)) add(`The "${name}" attribute cannot contain placeholders.`);
    }
    if (attrText.replace(consumed, "").trim()) add(`The <${tag}> tag has an attribute that is not written correctly.`);
    if (tag === "img" && !/\balt\s*=/i.test(attrText)) add("Every image needs an alt text, for readers whose email app hides images.");
    if (!VOID.has(tag) && !selfClosed) stack.push(tag);
  }
  if (html.slice(last).includes("<")) add("A stray < character. Write &lt; for a literal less-than sign.");
  if (stack.length) add(`The <${stack[stack.length - 1]}> tag is never closed.`);
  return errors;
}

// ---------- branding and layout ----------

export type Brand = { brand_name: string; logo_url: string | null; accent: string; footer_note: string; support_email: string; address: string };
export const DEFAULT_BRAND: Brand = { brand_name: "DROP", logo_url: null, accent: "#FF8A00", footer_note: "You are receiving this email because of activity on your DROP account.", support_email: "", address: "" };

export function normaliseBrand(v: unknown): Brand {
  const o = (v && typeof v === "object" ? v : {}) as Record<string, unknown>;
  const text = (x: unknown, max: number, d: string) => { const s = cleanLine(x, max); return s || d; };
  const accent = /^#[0-9a-fA-F]{6}$/.test(String(o.accent ?? "")) ? String(o.accent).toUpperCase() : DEFAULT_BRAND.accent;
  const email = String(o.support_email ?? "").trim();
  return {
    brand_name: text(o.brand_name, 40, DEFAULT_BRAND.brand_name),
    logo_url: safeUrl(o.logo_url) || null,
    accent,
    footer_note: o.footer_note === undefined ? DEFAULT_BRAND.footer_note : cleanLine(o.footer_note, 200),
    support_email: /^[^\s@<>"']+@[^\s@<>"']+\.[^\s@<>"']+$/.test(email) && email.length <= 80 ? email : "",
    address: cleanLine(o.address, 200),
  };
}

/** Dark text on light accents, white text on dark accents, so the button is readable whatever colour Admin picks. */
export function readableOn(hex: string): string {
  const c = [1, 3, 5].map((i) => parseInt(hex.slice(i, i + 2), 16) / 255).map((v) => (v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4));
  const lum = 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2];
  return lum > 0.35 ? "#16181D" : "#FFFFFF";
}

export type Scheme = "light" | "dark";

/**
 * Wraps the template's fragment in a branded, mobile-friendly shell. Email apps handle dark mode in three different ways:
 *  1. some apply the message's own @media (prefers-color-scheme: dark) rules: those are provided below;
 *  2. some (Outlook apps) look for [data-ogsc]/[data-ogsb] attributes: also provided;
 *  3. some invert colours on their own (Gmail on Android/iOS): so the shell sets explicit backgrounds and text colours
 *     on every block, uses no pure white or pure black, and keeps the logo on its own light plate.
 * `scheme` only controls what the Admin preview shows; real inboxes decide for themselves.
 */
export function wrapEmail(fragment: string, o: { brand: Brand; preheader?: string; title: string; scheme?: Scheme }): string {
  const b = o.brand, btnText = readableOn(b.accent);
  const dark = o.scheme === "dark";
  const bg = dark ? "#121212" : "#F4F5F7", card = dark ? "#1E1E1E" : "#FFFFFF", text = dark ? "#EDEDED" : "#1B2430", muted = dark ? "#A8A8A8" : "#5B6270", line = dark ? "#333333" : "#E3E6EA";
  const pre = o.preheader ? `<div style="display:none;font-size:1px;line-height:1px;max-height:0;max-width:0;opacity:0;overflow:hidden;mso-hide:all">${escapeHtml(o.preheader)}&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;</div>` : "";
  const logo = b.logo_url
    ? `<img src="${escapeHtml(b.logo_url)}" alt="${escapeHtml(b.brand_name)}" height="40" style="display:block;border:0;height:40px;max-width:180px">`
    : `<span style="font-size:22px;font-weight:800;letter-spacing:1px;color:${b.accent}">${escapeHtml(b.brand_name)}</span>`;
  const footer = [b.footer_note, b.support_email ? `Need help? ${b.support_email}` : "", b.address].filter(Boolean).map(escapeHtml).join("<br>");
  return `<!doctype html>
<html lang="en" xmlns="http://www.w3.org/1999/xhtml">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="color-scheme" content="light dark">
<meta name="supported-color-schemes" content="light dark">
<title>${escapeHtml(o.title)}</title>
<style>
  :root { color-scheme: light dark; supported-color-schemes: light dark; }
  body { margin:0; padding:0; width:100% !important; -webkit-text-size-adjust:100%; -ms-text-size-adjust:100%; }
  img { -ms-interpolation-mode:bicubic; }
  a.btn { background-color:${b.accent} !important; color:${btnText} !important; }
  .muted { color:${muted}; }
  .code { font-size:30px; font-weight:800; letter-spacing:6px; }
  @media only screen and (max-width:620px) { .wrap { width:100% !important; } .pad { padding:22px 18px !important; } }
  @media (prefers-color-scheme: dark) {
    body, .bg { background-color:#121212 !important; }
    .card { background-color:#1E1E1E !important; }
    .txt, .txt * { color:#EDEDED !important; }
    .muted, .muted * { color:#A8A8A8 !important; }
    .rule { border-color:#333333 !important; }
    a.btn { background-color:${b.accent} !important; color:${btnText} !important; }
  }
  [data-ogsc] .txt, [data-ogsc] .txt * { color:#EDEDED !important; }
  [data-ogsc] .muted { color:#A8A8A8 !important; }
  [data-ogsb] .bg { background-color:#121212 !important; }
  [data-ogsb] .card { background-color:#1E1E1E !important; }
</style>
</head>
<body class="bg" style="margin:0;padding:0;background-color:${bg}">
${pre}
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" class="bg" bgcolor="${bg}" style="background-color:${bg}">
<tr><td align="center" style="padding:24px 12px">
  <table role="presentation" width="600" cellpadding="0" cellspacing="0" border="0" class="wrap" style="width:600px;max-width:600px">
    <tr><td style="padding:0 4px 16px 4px">${logo}</td></tr>
    <tr><td class="card pad" bgcolor="${card}" style="background-color:${card};border:1px solid ${line};border-radius:12px;padding:30px 28px">
      <div class="txt" style="color:${text};font-family:-apple-system,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;font-size:16px;line-height:1.55">${fragment}</div>
    </td></tr>
    <tr><td class="muted" style="padding:18px 8px 0 8px;color:${muted};font-family:-apple-system,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;font-size:12px;line-height:1.5;text-align:center">${footer}</td></tr>
  </table>
</td></tr>
</table>
</body>
</html>`;
}

// ---------- validation ----------

export type EmailTemplateInput = {
  key?: string; name: string; category: string; audience: string;
  subject: string; preheader?: string | null; html_body: string; text_body: string;
};

/** Returns field -> messages. Empty means valid. `variables` is derived here, never taken from the client. */
export function validateEmailTemplate(t: EmailTemplateInput, ctx: { checkKey?: boolean } = {}): { errors: Record<string, string[]>; variables: string[] } {
  const errors: Record<string, string[]> = {};
  const add = (f: string, m: string) => (errors[f] ??= []).push(m);
  if (ctx.checkKey !== false) {
    if (!t.key || !/^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$/.test(t.key) || t.key.length > 80) add("key", "Use lowercase words joined by dots, like email.passenger.ride_receipt.");
  }
  const name = (t.name ?? "").trim();
  if (name.length < 2 || name.length > 120) add("name", "Enter a name (2 to 120 characters).");
  if (!CATEGORIES[t.category]) add("category", "Choose a category.");
  if (!(AUDIENCES as readonly string[]).includes(t.audience)) add("audience", "Choose who receives it.");
  const subject = (t.subject ?? "").trim(), html = (t.html_body ?? "").trim(), text = (t.text_body ?? "").trim(), pre = (t.preheader ?? "").trim();
  if (!subject || subject.length > 150) add("subject", "Enter a subject (up to 150 characters).");
  if (/[<>\r\n]/.test(subject)) add("subject", "The subject must be one line of plain text.");
  if (pre.length > 150) add("preheader", "The preview line can be up to 150 characters.");
  if (/[<>]/.test(pre)) add("preheader", "The preview line must be plain text.");
  if (!html || html.length > 40000) add("html_body", "Enter the email body (up to 40,000 characters).");
  if (!text || text.length > 20000) add("text_body", "Enter the plain-text version (up to 20,000 characters). Some email apps show only this.");
  const vars: string[] = [];
  const checkText = (field: string, s: string, allowSensitive = true) => {
    if (!s) return;
    const p = placeholders(s);
    if (p.malformed) add(field, "A placeholder is not written correctly. Use {{name}} with letters and underscores only.");
    const unknown = p.names.filter((n) => !isVar(n));
    if (unknown.length) add(field, `Unknown placeholder: ${unknown.map((n) => `{{${n}}}`).join(", ")}.`);
    if (!allowSensitive && p.names.some((n) => isVar(n) && VARIABLES[n].sensitive)) add(field, "The subject and preview line are shown on lock screens, so they cannot contain a code or secure link.");
    for (const n of p.names) if (isVar(n) && !vars.includes(n)) vars.push(n);
  };
  checkText("subject", subject, false); checkText("preheader", pre, false); checkText("html_body", html); checkText("text_body", text);
  if (html && !errors.html_body) for (const m of checkHtml(html)) add("html_body", m);
  return { errors, variables: vars };
}

export type RenderedEmail = { subject: string; preheader: string; html: string; text: string };

/** Fills the template. `mask` hides sensitive values (for logs and previews of delivered mail). Throws nothing: bad HTML yields an error string. */
export function renderEmail(t: { subject: string; preheader?: string | null; html_body: string; text_body: string }, values: Record<string, unknown>, brand: Brand,
  opts: { mask?: boolean; scheme?: Scheme } = {}): { ok: true; email: RenderedEmail } | { ok: false; error: string } {
  const problems = checkHtml(t.html_body);
  if (problems.length) return { ok: false, error: `The email body is not safe to send: ${problems[0]}` };
  const all = { ...values, brand_name: brand.brand_name, support_email: brand.support_email };
  const subject = renderTemplateText(t.subject, all, "subject", opts.mask);
  const preheader = renderTemplateText(t.preheader ?? "", all, "subject", opts.mask);
  const fragment = renderTemplateText(t.html_body, all, "html", opts.mask);
  const footer = [brand.footer_note, brand.support_email ? `Need help? ${brand.support_email}` : "", brand.address].filter(Boolean).join("\n");
  const text = `${renderTemplateText(t.text_body, all, "text", opts.mask)}\n\n--\n${brand.brand_name}${footer ? `\n${footer}` : ""}`;
  return { ok: true, email: { subject, preheader, html: wrapEmail(fragment, { brand, preheader, title: subject || brand.brand_name, scheme: opts.scheme }), text } };
}

// ---------- built-in catalogue ----------

export type EmailEventDef = {
  key: string; name: string; audience: "passenger" | "driver" | "system"; category: string;
  subject: string; preheader: string; html: string; text: string;
  /** Does some event in the Worker send this today? Unconnected templates are kept ready but nothing fires them. */
  wired: boolean;
  /** Critical: cannot be switched off or archived, and falls back to the built-in text, so nobody is locked out (password reset). */
  locked?: boolean;
  /** Newly connected in Phase 5: seeded switched off, so merging changes nothing until an admin turns it on. */
  fresh?: boolean;
  note?: string;
};

type Spec = { h: string; p: string[]; rows?: [string, string][]; btn?: [string, string]; code?: string; after?: string[] };

const P = `margin:0 0 14px`;
function build(spec: Spec): { html: string; text: string } {
  const html: string[] = [`<h1 style="margin:0 0 16px;font-size:22px;line-height:1.3;font-weight:800">${spec.h}</h1>`];
  const text: string[] = [spec.h, ""];
  for (const para of spec.p) { html.push(`<p style="${P}">${para}</p>`); text.push(para, ""); }
  if (spec.code) {
    html.push(`<p class="code" style="margin:18px 0;font-size:30px;font-weight:800;letter-spacing:6px">{{${spec.code}}}</p>`);
    text.push(`{{${spec.code}}}`, "");
  }
  for (const para of spec.after ?? []) { html.push(`<p style="${P}">${para}</p>`); text.push(para, ""); }
  if (spec.rows?.length) {
    html.push(`<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="margin:6px 0 18px;border-collapse:collapse">`);
    for (const [label, v] of spec.rows) {
      html.push(`<tr><td class="muted" style="padding:9px 0;border-bottom:1px solid rgba(128,128,128,.35);font-size:14px;opacity:.85">${label}</td><td align="right" style="padding:9px 0;border-bottom:1px solid rgba(128,128,128,.35);font-size:14px;font-weight:700">{{${v}}}</td></tr>`);
      text.push(`${label}: {{${v}}}`);
    }
    html.push(`</table>`); text.push("");
  }
  if (spec.btn) {
    html.push(`<p style="margin:22px 0"><a class="btn" href="{{${spec.btn[1]}}}" style="display:inline-block;padding:13px 22px;border-radius:8px;background-color:#FF8A00;color:#16181D;font-weight:700;text-decoration:none">${spec.btn[0]}</a></p>`);
    text.push(`${spec.btn[0]}: {{${spec.btn[1]}}}`, "");
  }
  return { html: html.join("\n"), text: text.join("\n").trim() };
}

const NOT_YET = "Not connected yet: DROP has no event that sends this today.";

function E(key: string, name: string, audience: EmailEventDef["audience"], category: string, subject: string, preheader: string, spec: Spec,
  wired = false, extra: Partial<EmailEventDef> = {}): EmailEventDef {
  const b = build(spec);
  return { key, name, audience, category, subject, preheader, html: b.html, text: b.text, wired, ...extra };
}

export const EMAIL_EVENTS: EmailEventDef[] = [
  // ---- Passenger ----
  E("email.passenger.welcome", "Welcome", "passenger", "account", "Welcome to {{brand_name}}", "Your account is ready.",
    { h: "Welcome, {{recipient_name}}", p: ["Your {{brand_name}} account is ready. Open the app, set your pickup and destination, and a driver will be on the way.", "If you did not create this account, please contact us at {{support_email}}."] },
    false, { note: "Not connected: sign-up does not collect or confirm an email address yet." }),
  E("email.passenger.account_verification", "Account verification", "passenger", "verification", "Confirm your email for {{brand_name}}", "Use this link to confirm your email address.",
    { h: "Confirm your email", p: ["Hi {{recipient_name}}, please confirm this email address for your {{brand_name}} account. The link works for {{expires_in}}.", "If you did not ask for this, you can ignore this email."], btn: ["Confirm email", "secure_link"] },
    false, { note: "Not connected: email confirmation is not part of sign-up yet." }),
  E("email.passenger.otp", "Sign-in code", "passenger", "verification", "Your {{brand_name}} code", "Your code expires in {{expires_in}}.",
    { h: "Your verification code", p: ["Use this code to continue. It is valid for {{expires_in}}.", "Never share this code with anyone, including {{brand_name}} staff."], code: "code" },
    false, { note: "Not connected: sign-in codes go by SMS or WhatsApp today, not email." }),
  E("email.passenger.password_reset", "Password reset code", "passenger", "verification", "Your {{brand_name}} password reset code", "Your code expires in {{expires_in}}.",
    { h: "Reset your password", p: ["Hi {{recipient_name}},", "Your {{brand_name}} password reset code is:"], code: "code", after: ["It is valid for {{expires_in}}. If you did not ask for this, you can ignore this email: your password has not changed."] },
    true, { locked: true, note: "Always on: people could not reset a forgotten password if this were switched off." }),
  E("email.passenger.ride_confirmed", "Ride confirmation", "passenger", "ride", "Your {{brand_name}} ride request #{{ride_id}}", "We are finding a driver.",
    { h: "We received your ride request", p: ["Hi {{recipient_name}}, we are finding a driver for your trip."], rows: [["Ride number", "ride_id"], ["From", "pickup_location"], ["To", "destination"], ["Fare", "fare"]] },
    true, { fresh: true }),
  E("email.passenger.driver_assigned", "Driver assigned", "passenger", "ride", "Your driver is on the way", "{{driver_name}} accepted your ride.",
    { h: "A driver accepted your ride", p: ["Hi {{recipient_name}}, {{driver_name}} is heading to your pickup point."], rows: [["Ride number", "ride_id"], ["Driver", "driver_name"], ["Pickup", "pickup_location"]] },
    true, { fresh: true }),
  E("email.passenger.scheduled_confirmed", "Scheduled ride confirmation", "passenger", "ride", "Your scheduled ride is confirmed", "Your ride is booked for {{scheduled_time}}.",
    { h: "Your scheduled ride is confirmed", p: ["Hi {{recipient_name}}, your ride is booked."], rows: [["Pickup time", "scheduled_time"], ["From", "pickup_location"], ["To", "destination"]] },
    false, { note: NOT_YET + " Scheduled rides do not exist yet." }),
  E("email.passenger.airport_confirmed", "Airport booking confirmation", "passenger", "airport", "Your airport booking #{{ride_id}}", "We are finding a driver for your airport trip.",
    { h: "Your airport booking is received", p: ["Hi {{recipient_name}}, we are finding a driver for your airport transfer."], rows: [["Booking number", "ride_id"], ["Airport", "airport_name"], ["Terminal", "terminal"], ["Pickup", "pickup_location"], ["Drop-off", "destination"]] },
    true, { fresh: true }),
  E("email.passenger.airport_pickup_info", "Airport Pickup information", "passenger", "airport", "Your airport pickup details", "Where and how to meet your driver.",
    { h: "Your airport pickup", p: ["Hi {{recipient_name}}, here is what to know for your arrival.", "{{note}}"], rows: [["Airport", "airport_name"], ["Terminal", "terminal"], ["Flight", "flight_number"], ["Driver", "driver_name"]] },
    false, { note: NOT_YET + " Meeting-point details are sent only once an admin has verified them for that airport." }),
  E("email.passenger.airport_drop_info", "Airport Drop information", "passenger", "airport", "Your airport drop details", "What to know for your trip to the airport.",
    { h: "Your trip to the airport", p: ["Hi {{recipient_name}}, here is what to know for your trip.", "{{note}}"], rows: [["Airport", "airport_name"], ["Terminal", "terminal"], ["Flight", "flight_number"], ["Pickup time", "scheduled_time"]] },
    false, { note: NOT_YET }),
  E("email.passenger.ride_receipt", "Ride receipt", "passenger", "payment", "Your {{brand_name}} receipt for trip #{{ride_id}}", "Thanks for riding with {{brand_name}}.",
    { h: "Thanks for riding with {{brand_name}}", p: ["Hi {{recipient_name}}, here is your receipt."], rows: [["Trip number", "ride_id"], ["Date", "ride_date"], ["From", "pickup_location"], ["To", "destination"], ["Driver", "driver_name"], ["Total", "fare"]] },
    true, { fresh: true }),
  E("email.passenger.payment_confirmed", "Payment confirmation", "passenger", "payment", "We received your payment of {{amount}}", "Payment confirmed.",
    { h: "Payment received", p: ["Hi {{recipient_name}}, thank you. We received your payment."], rows: [["Amount", "amount"], ["Method", "payment_method"], ["Reference", "reference"]] },
    false, { note: NOT_YET }),
  E("email.passenger.refund", "Refund notification", "passenger", "payment", "Your refund of {{refund_amount}}", "Your refund is on its way.",
    { h: "Your refund is on its way", p: ["Hi {{recipient_name}}, we refunded part or all of a payment."], rows: [["Refund", "refund_amount"], ["Reference", "reference"], ["Trip number", "ride_id"]] },
    false, { note: NOT_YET + " Refunds do not send an email today." }),
  E("email.passenger.wallet_update", "Wallet update", "passenger", "wallet", "Your {{brand_name}} wallet was credited", "{{amount}} was added to your wallet.",
    { h: "Your wallet was credited", p: ["Hi {{recipient_name}}, {{amount}} {{reason}}"] },
    true, { fresh: true }),
  E("email.passenger.referral", "Referral", "passenger", "promotion", "Thanks for spreading the word", "Your referral joined {{brand_name}}.",
    { h: "Your referral joined", p: ["Hi {{recipient_name}}, someone you invited joined {{brand_name}}. Your reward: {{referral_bonus}}."] },
    false, { note: "Not connected: referrals are not built yet." }),
  E("email.passenger.support_update", "Support update", "passenger", "support", "Update on your support request {{ticket_id}}", "We have news about your request.",
    { h: "An update from Support", p: ["Hi {{recipient_name}},", "{{note}}"], rows: [["Request", "ticket_id"]] },
    false, { note: NOT_YET }),
  E("email.passenger.security_notice", "Security notification", "passenger", "verification", "Security alert for your {{brand_name}} account", "We noticed activity on your account.",
    { h: "Security alert", p: ["Hi {{recipient_name}}, we noticed this activity on your account:", "{{note}}", "If this was not you, reset your password and contact {{support_email}}."], rows: [["When", "event_time"], ["Device", "device"]] },
    false, { note: NOT_YET }),

  // ---- Driver ----
  E("email.driver.application_received", "Driver application received", "driver", "driver_account", "We received your {{brand_name}} driver application", "We will review it shortly.",
    { h: "We received your application", p: ["Hi {{recipient_name}}, thank you for applying to drive with {{brand_name}}. Our team will review it and email you the result."] },
    false, { note: "Not connected: submitting an application does not send an email yet." }),
  E("email.driver.application_approved", "Application approved", "driver", "driver_account", "You are approved to drive with {{brand_name}}", "Welcome to the team.",
    { h: "You are approved", p: ["Hi {{recipient_name}}, your driver application was approved. Open the app, switch to driver mode from the menu, and go online to start earning."] },
    true, { fresh: true }),
  E("email.driver.application_rejected", "Application not approved", "driver", "driver_account", "About your {{brand_name}} driver application", "An update on your application.",
    { h: "Your application was not approved", p: ["Hi {{recipient_name}}, thank you for applying. We could not approve your application this time.", "{{note}}"] },
    true, { fresh: true }),
  E("email.driver.account_activated", "Account activation", "driver", "driver_account", "Your {{brand_name}} driver account is active", "Driver mode is on.",
    { h: "Your driver account is active", p: ["Hi {{recipient_name}}, driver mode is on again. You can go online and accept rides."] },
    true, { fresh: true }),
  E("email.driver.document_approved", "Document approved", "driver", "documents", "Your {{document_name}} was approved", "Your document is verified.",
    { h: "Document approved", p: ["Hi {{recipient_name}}, your {{document_name}} was approved. No action is needed."] },
    false, { note: NOT_YET }),
  E("email.driver.document_expiring", "Document expiry reminder", "driver", "documents", "Your {{document_name}} expires on {{expiry_date}}", "Upload a new one to keep driving.",
    { h: "A document is expiring", p: ["Hi {{recipient_name}}, your {{document_name}} expires on {{expiry_date}}. Please upload a new one in the app so you can keep driving."] },
    false, { note: NOT_YET + " No job checks document expiry dates yet." }),
  E("email.driver.account_warning", "Account warning", "driver", "driver_account", "Important notice about your {{brand_name}} account", "Please read this notice.",
    { h: "Account warning", p: ["Hi {{recipient_name}}, we need to bring something to your attention.", "{{note}}", "If you have questions, contact {{support_email}}."] },
    false, { note: NOT_YET }),
  E("email.driver.suspension", "Suspension notice", "driver", "driver_account", "Your {{brand_name}} driver account is suspended", "Driver mode is paused.",
    { h: "Your driver account is suspended", p: ["Hi {{recipient_name}}, driver mode is paused on your account. Please contact {{support_email}} to find out why and what to do next."] },
    true, { fresh: true }),
  E("email.driver.earnings_statement", "Earnings statement", "driver", "earnings", "Your {{brand_name}} earnings for {{period}}", "Your earnings summary.",
    { h: "Your earnings statement", p: ["Hi {{recipient_name}}, here is your summary."], rows: [["Period", "period"], ["Trips", "trips_count"], ["Total earnings", "earnings_total"]] },
    false, { note: NOT_YET + " Statements are not generated yet." }),
  E("email.driver.payout_confirmed", "Payout confirmation", "driver", "earnings", "Your payout of {{payout_amount}}", "Your payout was sent.",
    { h: "Your payout was sent", p: ["Hi {{recipient_name}}, we sent your payout."], rows: [["Amount", "payout_amount"], ["To", "payout_destination"], ["Reference", "reference"]] },
    false, { note: NOT_YET + " Payouts do not send an email today." }),
  E("email.driver.airport_booking_info", "Airport booking information", "driver", "airport", "Airport booking #{{ride_id}}", "Details of your airport booking.",
    { h: "Your airport booking", p: ["Hi {{recipient_name}}, you accepted an airport booking.", "{{note}}"], rows: [["Airport", "airport_name"], ["Terminal", "terminal"], ["Pickup", "pickup_location"], ["Flight", "flight_number"]] },
    false, { note: NOT_YET }),
  E("email.driver.security_notice", "Security notification", "driver", "verification", "Security alert for your {{brand_name}} account", "We noticed activity on your account.",
    { h: "Security alert", p: ["Hi {{recipient_name}}, we noticed this activity on your account:", "{{note}}", "If this was not you, reset your password and contact {{support_email}}."], rows: [["When", "event_time"], ["Device", "device"]] },
    false, { note: NOT_YET }),

  // ---- System ----
  E("email.system.security_notice", "Password and security notification", "system", "verification", "Your {{brand_name}} password was changed", "If this was not you, act now.",
    { h: "Your password was changed", p: ["Hi {{recipient_name}}, the password on your {{brand_name}} account was just changed.", "If this was you, no action is needed. If it was not, contact {{support_email}} straight away."], rows: [["When", "event_time"]] },
    true, { fresh: true }),
  E("email.system.account_change", "Account change", "system", "account", "A change was made to your {{brand_name}} account", "Please review this change.",
    { h: "Your account was updated", p: ["Hi {{recipient_name}}, this change was made to your account:", "{{note}}", "If you did not make it, contact {{support_email}}."], rows: [["When", "event_time"]] },
    false, { note: NOT_YET }),
  E("email.system.maintenance", "Maintenance announcement", "system", "announcement", "{{headline}}", "Planned maintenance notice.",
    { h: "{{headline}}", p: ["{{message}}"] },
    false, { note: "Not connected: sending announcements to many people is not built. Use Send test to check the wording." }),
  E("email.system.policy_update", "Policy update", "system", "announcement", "Update to our {{brand_name}} terms", "Changes take effect on {{effective_date}}.",
    { h: "We updated our policy", p: ["Hi {{recipient_name}}, {{message}}", "The changes take effect on {{effective_date}}."], btn: ["Read the details", "action_url"] },
    false, { note: "Not connected: sending announcements to many people is not built." }),
  E("email.system.service_notice", "Important service notification", "system", "announcement", "{{headline}}", "An important notice about {{brand_name}}.",
    { h: "{{headline}}", p: ["Hi {{recipient_name}},", "{{message}}"] },
    false, { note: "Not connected: sending announcements to many people is not built." }),
];

export const EMAIL_EVENT_BY_KEY = new Map(EMAIL_EVENTS.map((e) => [e.key, e]));
