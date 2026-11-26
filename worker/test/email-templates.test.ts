import { strict as assert } from "node:assert";
import {
  AUDIENCES, CATEGORIES, DEFAULT_BRAND, EMAIL_EVENTS, VARIABLES, checkHtml, escapeHtml, isVar, normaliseBrand, placeholders, readableOn, renderEmail,
  renderTemplateText, safeUrl, sampleValues, usesSensitive, validateEmailTemplate, wrapEmail,
} from "../src/lib/email-templates";

const base = { name: "Test", category: "ride", audience: "passenger", subject: "Hi {{recipient_name}}", html_body: "<p>Hello {{recipient_name}}</p>", text_body: "Hello {{recipient_name}}" };
const errs = (o: Record<string, unknown>) => validateEmailTemplate({ ...base, ...o } as never, { checkKey: false }).errors;

// ---- placeholders: only {{name}} with letters/underscores; hostile and inherited names are refused, never evaluated
assert.deepEqual(placeholders("Hi {{recipient_name}} {{ ride_id }}").names, ["recipient_name", "ride_id"]);
assert.ok(placeholders("{{recipient_name").malformed);
for (const bad of ["{{process.env.X}}", "{{constructor}}", "{{__proto__}}", "{{toString}}", "{{#each}}", "{{ code"]) assert.ok(errs({ text_body: bad }).text_body, bad);
assert.ok(!isVar("constructor") && !isVar("__proto__") && isVar("code"));
assert.equal(renderTemplateText("{{constructor}}|{{__proto__}}", {}, "text"), "|");
assert.equal(renderTemplateText("{{constructor}}", { constructor: "leak" }, "text"), "");

// ---- values: single pass, escaped, capped, links must be https, subject is one line
assert.equal(renderTemplateText("Hi {{recipient_name}}", { recipient_name: "{{code}}", code: "9999" }, "text"), "Hi {{code}}", "never expanded twice");
assert.equal(renderTemplateText("<p>{{recipient_name}}</p>", { recipient_name: `<script>alert("x")</script>&'` }, "html"), "<p>&lt;script&gt;alert(&quot;x&quot;)&lt;/script&gt;&amp;&#39;</p>");
assert.equal(renderTemplateText("{{recipient_name}}", { recipient_name: "A".repeat(100) }, "text").length, VARIABLES.recipient_name.max);
assert.equal(renderTemplateText("S: {{note}}", { note: "line1\r\nBcc: evil@x.com" }, "subject"), "S: line1 Bcc: evil@x.com", "no header injection through the subject");
assert.equal(safeUrl("https://example.com/a?b=1"), "https://example.com/a?b=1");
for (const bad of ["javascript:alert(1)", "http://example.com", "data:text/html,x", "https://user:pw@example.com", "https://x.com/a b", "//evil.com", ""]) assert.equal(safeUrl(bad), "", bad);
assert.equal(renderTemplateText("{{action_url}}", { action_url: "javascript:alert(1)" }, "html"), "", "a bad link value renders empty");
assert.equal(renderTemplateText("Code {{code}}", { code: "123456" }, "text", true), "Code ••••");

// ---- the HTML allow-list refuses, it does not "clean"
const bad = (html: string) => checkHtml(html).length > 0;
for (const html of [
  "<script>alert(1)</script>", "<p onclick=\"x()\">hi</p>", "<iframe src=\"https://x.com\"></iframe>", "<form action=\"https://x.com\"><input></form>",
  "<a href=\"javascript:alert(1)\">x</a>", "<a href=\"JaVaScRiPt:alert(1)\">x</a>", "<a href=\"data:text/html;base64,AAA\">x</a>", "<a href=\"http://x.com\">x</a>",
  "<a href=\"{{recipient_name}}\">x</a>", "<img src=\"data:image/png;base64,AAA\" alt=\"x\">", "<img src=\"http://x.com/a.png\" alt=\"x\">", "<img src=\"https://x.com/a.png\">",
  "<p style=\"background:url(https://x.com/a.png)\">x</p>", "<p style=\"width:expression(alert(1))\">x</p>", "<p style=\"position:fixed\">x</p>", "<p style=\"color:red;@import 'x'\">x</p>",
  "<style>p{color:red}</style>", "<link rel=\"stylesheet\" href=\"https://x.com/a.css\">", "<meta http-equiv=\"refresh\" content=\"0\">", "<object data=\"x\"></object>", "<svg onload=\"x()\"></svg>",
  "<!-- comment -->", "<!--[if mso]><p>x</p><![endif]-->", "<p>1 < 2</p>", "<p class=\"evil\">x</p>", "<p id=\"x\">x</p>", "<p>unclosed", "<div><p>mismatch</div></p>", "</p>", "<br></br>",
  "<a href=\"https://x.com\" target=\"_blank\">x</a>", "<p data-x=\"1\">x</p>", "<base href=\"https://evil.com/\">", "<p style=\"color:red\" style2>x</p>",
]) assert.ok(bad(html), html);
for (const html of [
  "<p>Hello</p>", "<h1 style=\"margin:0 0 16px;font-size:22px\">Hi</h1><p class=\"muted\">x</p>", "<a class=\"btn\" href=\"{{action_url}}\">Open</a>", "<a href=\"https://example.com/x?y=1&amp;z=2\">x</a>",
  "<a href=\"mailto:help@example.com\">mail</a>", "<a href=\"tel:+2348000000000\">call</a>", "<img src=\"https://example.com/logo.png\" alt=\"Logo\" width=\"120\">",
  "<table role=\"presentation\" width=\"100%\"><tr><td align=\"right\">1 &lt; 2</td></tr></table>", "<ul><li>a</li><li>b</li></ul>", "<br><hr><p>a<br/>b</p>",
]) assert.deepEqual(checkHtml(html), [], html);

// ---- template validation
assert.deepEqual(errs({}), {});
assert.ok(errs({ subject: "" }).subject && errs({ subject: "a\nb" }).subject && errs({ subject: "<b>x</b>" }).subject);
assert.ok(errs({ subject: "Your code {{code}}" }).subject, "a code cannot be in the subject");
assert.ok(errs({ preheader: "Use {{secure_link}}" }).preheader, "nor in the preview line");
assert.ok(!errs({ html_body: "<p>Your code {{code}}</p>" }).html_body, "the body may carry the code");
assert.ok(errs({ text_body: "" }).text_body && errs({ html_body: "" }).html_body, "both versions are required");
assert.ok(errs({ category: "nope" }).category && errs({ audience: "everyone" }).audience);
assert.ok(validateEmailTemplate({ ...base, key: "Bad Key" }).errors.key && !validateEmailTemplate({ ...base, key: "email.passenger.x_1" }).errors.key);
assert.deepEqual(validateEmailTemplate({ ...base, html_body: "<p>{{ride_id}} {{fare}}</p>", subject: "x", text_body: "{{ride_id}}" }).variables.sort(), ["fare", "ride_id"]);
assert.ok(usesSensitive("x {{code}}") && usesSensitive("{{secure_link}}") && !usesSensitive("{{ride_id}}", null));

// ---- rendering and the layout
const tpl = { subject: "Ride {{ride_id}}", preheader: "Hi {{recipient_name}}", html_body: "<p>{{recipient_name}} <a class=\"btn\" href=\"{{action_url}}\">Open</a></p>", text_body: "Open: {{action_url}}" };
const ok = renderEmail(tpl, { ride_id: "7", recipient_name: "<b>Ann</b>", action_url: "https://example.com/r/7" }, DEFAULT_BRAND);
assert.ok(ok.ok);
if (ok.ok) {
  const e = ok.email;
  assert.equal(e.subject, "Ride 7");
  assert.ok(e.html.includes("&lt;b&gt;Ann&lt;/b&gt;") && !e.html.includes("<b>Ann</b>") && e.html.includes("href=\"https://example.com/r/7\""));
  assert.ok(!/<script/i.test(e.html) && !/\son[a-z]+\s*=/i.test(e.html), "no script and no event handlers in the final email");
  assert.ok(e.text.startsWith("Open: https://example.com/r/7") && e.text.includes(DEFAULT_BRAND.brand_name));
  // dark-mode support for each family of email apps
  assert.ok(e.html.includes("<meta name=\"color-scheme\" content=\"light dark\">") && e.html.includes("prefers-color-scheme: dark") && e.html.includes("[data-ogsc]"));
  assert.ok(e.html.includes("max-width:620px") && e.html.includes("name=\"viewport\""), "responsive");
  assert.ok(!/#000000|#000\b|#FFFFFF;?\s*"?>\s*<div class="txt/.test(e.html) && e.html.includes("bgcolor="), "explicit backgrounds and no pure black text");
  assert.ok(e.html.includes("display:none") && e.html.includes("Hi &lt;b&gt;Ann&lt;/b&gt;"), "hidden preview line, escaped");
}
const dark = renderEmail(tpl, {}, DEFAULT_BRAND, { scheme: "dark" }), light = renderEmail(tpl, {}, DEFAULT_BRAND, { scheme: "light" });
assert.ok(dark.ok && light.ok && dark.ok && light.ok && dark.email.html !== light.email.html && dark.email.html.includes("#121212"));
const unsafe = renderEmail({ ...tpl, html_body: "<script>x</script>" }, {}, DEFAULT_BRAND);
assert.ok(!unsafe.ok, "unsafe HTML is refused at send time too");
const masked = renderEmail({ subject: "x", html_body: "<p>{{code}}</p>", text_body: "{{code}}" }, { code: "123456" }, DEFAULT_BRAND, { mask: true });
assert.ok(masked.ok && masked.ok && !masked.email.html.includes("123456") && !masked.email.text.includes("123456"));
assert.ok(escapeHtml("<>&\"'") === "&lt;&gt;&amp;&quot;&#39;");

// ---- branding is validated, and button text stays readable on any accent
assert.equal(normaliseBrand({ accent: "red" }).accent, DEFAULT_BRAND.accent);
assert.equal(normaliseBrand({ accent: "#0b7a4b" }).accent, "#0B7A4B");
assert.equal(normaliseBrand({ logo_url: "http://x.com/a.png" }).logo_url, null);
assert.equal(normaliseBrand({ logo_url: "https://x.com/a.png" }).logo_url, "https://x.com/a.png");
assert.equal(normaliseBrand({ support_email: "not an email" }).support_email, "");
assert.equal(normaliseBrand({ brand_name: "<script>" }).brand_name, "<script>", "stored as text; always escaped when rendered");
assert.ok(wrapEmail("<p>x</p>", { brand: normaliseBrand({ brand_name: "<script>alert(1)</script>" }), title: "t" }).indexOf("<script>alert(1)") === -1, "a hostile brand name is escaped in the layout");
assert.equal(readableOn("#FF8A00"), "#16181D");
assert.equal(readableOn("#0B3D2E"), "#FFFFFF");

// ---- the built-in catalogue
const keys = EMAIL_EVENTS.map((e) => e.key);
assert.equal(new Set(keys).size, keys.length, "keys are unique");
for (const e of EMAIL_EVENTS) {
  assert.ok(/^email\.(passenger|driver|system)\.[a-z0-9_]+$/.test(e.key), e.key);
  assert.equal(e.key.split(".")[1], e.audience, e.key + " audience matches its key");
  assert.ok(CATEGORIES[e.category] && (AUDIENCES as readonly string[]).includes(e.audience), e.key);
  const v = validateEmailTemplate({ key: e.key, name: e.name, category: e.category, audience: e.audience, subject: e.subject, preheader: e.preheader, html_body: e.html, text_body: e.text });
  assert.deepEqual(v.errors, {}, e.key + " " + JSON.stringify(v.errors));
  const r = renderEmail({ subject: e.subject, preheader: e.preheader, html_body: e.html, text_body: e.text }, sampleValues(), DEFAULT_BRAND);
  assert.ok(r.ok && r.ok && !/\{\{|\}\}/.test(r.email.html + r.email.text + r.email.subject), e.key + " renders with every placeholder filled");
  if (!e.wired) assert.ok(e.note, e.key + " explains why it is not connected");
  assert.ok(!(e.fresh && !e.wired), e.key + " fresh implies wired");
}
const count = (a: string) => EMAIL_EVENTS.filter((e) => e.audience === a).length;
assert.ok(count("passenger") >= 17 && count("driver") >= 12 && count("system") >= 5, "every required template is present");
for (const k of [
  "email.passenger.welcome", "email.passenger.account_verification", "email.passenger.otp", "email.passenger.password_reset", "email.passenger.ride_confirmed", "email.passenger.driver_assigned",
  "email.passenger.scheduled_confirmed", "email.passenger.airport_confirmed", "email.passenger.airport_pickup_info", "email.passenger.airport_drop_info", "email.passenger.ride_receipt",
  "email.passenger.payment_confirmed", "email.passenger.refund", "email.passenger.wallet_update", "email.passenger.referral", "email.passenger.support_update", "email.passenger.security_notice",
  "email.driver.application_received", "email.driver.application_approved", "email.driver.application_rejected", "email.driver.account_activated", "email.driver.document_approved",
  "email.driver.document_expiring", "email.driver.account_warning", "email.driver.suspension", "email.driver.earnings_statement", "email.driver.payout_confirmed", "email.driver.airport_booking_info", "email.driver.security_notice",
  "email.system.security_notice", "email.system.account_change", "email.system.maintenance", "email.system.policy_update", "email.system.service_notice",
]) assert.ok(keys.includes(k), k);
// Only the password-reset email is on from the start (it already sent before). It is always on, and its code is never kept in the log.
assert.deepEqual(EMAIL_EVENTS.filter((e) => e.wired && !e.fresh).map((e) => e.key), ["email.passenger.password_reset"]);
assert.deepEqual(EMAIL_EVENTS.filter((e) => e.locked).map((e) => e.key), ["email.passenger.password_reset"]);
const reset = EMAIL_EVENTS.find((e) => e.key === "email.passenger.password_reset")!;
assert.ok(usesSensitive(reset.html) && !usesSensitive(reset.subject, reset.preheader));
// The 6-digit code must never be what a lock screen shows.
for (const e of EMAIL_EVENTS) assert.ok(!usesSensitive(e.subject, e.preheader), e.key + " subject and preview carry no code");

console.log("email-templates.test: all assertions passed");
