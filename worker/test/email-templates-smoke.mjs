// Email template management end to end against a disposable DB. Test/CI database only, never production.
// No real email is delivered: Resend is unconfigured, then given an invalid key, so this proves permissions, validation, safe HTML,
// CRUD, versioning and restore, audit, preview, search, branding, locked password reset, test-send logging, masking of codes,
// duplicate prevention at the database, failure logging, and that an email failure never breaks the request that caused it.
// Run: DATABASE_URL=... ADMIN_EMAIL=... ADMIN_PASSWORD=... node test/email-templates-smoke.mjs
import pg from "pg";
const API = (process.env.BASE ?? "http://127.0.0.1:8787") + "/api";
const { ADMIN_EMAIL, ADMIN_PASSWORD, DATABASE_URL } = process.env;
if (!ADMIN_EMAIL || !ADMIN_PASSWORD || !DATABASE_URL) throw new Error("set ADMIN_EMAIL, ADMIN_PASSWORD and DATABASE_URL");
const db = new pg.Client({ connectionString: DATABASE_URL }); await db.connect();
let fails = 0;
const ok = (n, c, extra = "") => { console.log(c ? "PASS" : "FAIL", n, c ? "" : extra); if (!c) fails++; };
const call = async (method, path, token, body) => {
  const r = await fetch(API + path, { method, headers: { Accept: "application/json", ...(body ? { "Content-Type": "application/json" } : {}), ...(token ? { Authorization: "Bearer " + token } : {}) }, body: body ? JSON.stringify(body) : undefined });
  return { status: r.status, json: await r.json().catch(() => ({})) };
};
const s = Math.random().toString(36).slice(2, 8);
const phone = () => "0803" + Math.floor(1000000 + Math.random() * 8999999);
const reg = async (type, tag) => (await call("POST", "/register", null, { first_name: "Em" + tag, last_name: tag + s, email: `${tag}${s}@x.com`, username: `${tag}${s}`, password: "secret123", user_type: type, contact_number: phone() })).json.data;
const A = (await call("POST", "/login", null, { email: ADMIN_EMAIL, password: ADMIN_PASSWORD, user_type: "admin" })).json.data?.api_token;
const keys = [], users = [];
const base = { name: "Smoke " + s, category: "promotion", audience: "passenger", subject: "Hello {{recipient_name}}", preheader: "Quick note", html_body: "<h1>Hi {{recipient_name}}</h1><p>Your ride {{ride_id}} is set.</p>", text_body: "Hi {{recipient_name}}\nYour ride {{ride_id}} is set." };
let resendConfigured = false;
try {
  const P = await reg("rider", "em"); users.push(P.id);
  const Q = await reg("rider", "eq"); users.push(Q.id);

  // ---- permissions
  ok("a rider cannot list email templates", (await call("GET", "/admin/email-templates", P.api_token)).status === 403);
  ok("a rider cannot create email templates", (await call("POST", "/admin/email-templates", P.api_token, { ...base, key: `email.passenger.smoke_${s}` })).status === 403);
  ok("a rider cannot read the email log", (await call("GET", "/admin/email-deliveries", P.api_token)).status === 403);
  ok("a rider cannot change branding", (await call("PUT", "/admin/email-branding", P.api_token, { brand_name: "X" })).status === 403);
  ok("signed-out requests are refused", (await call("GET", "/admin/email-templates", null)).status === 401);

  // ---- password reset keeps working before any template row exists, and never keeps the code
  const fp = await call("POST", "/forgot-password", null, { identifier: P.email ?? `em${s}@x.com` });
  ok("forgot-password still answers 200 when email cannot be sent", fp.status === 200, JSON.stringify(fp.json));
  const d0 = (await db.query("select * from app.email_deliveries where user_id = $1 and template_key = 'email.passenger.password_reset' order by id desc limit 1", [P.id])).rows[0];
  ok("the reset email is logged", !!d0 && d0.is_test === false);
  ok("the code is not kept: no body, masked subject", d0 && d0.sensitive === true && d0.html_body === null && d0.text_body === null && !/\d{6}/.test(d0.subject), JSON.stringify(d0 ?? {}).slice(0, 200));
  ok("an unconfigured provider is logged as a failure that is not retried", d0 && d0.status === "failed" && /not set up/i.test(d0.reason ?? "") && d0.retryable === false && d0.next_retry_at === null);

  // ---- built-in templates appear, with safe starting states
  const list = await call("GET", "/admin/email-templates?limit=100&status=all", A);
  const rows = list.json.data ?? [];
  const by = Object.fromEntries(rows.map((r) => [r.key, r]));
  ok("the list loads and built-ins are created", list.status === 200 && list.json.total >= 34, JSON.stringify(list.json).slice(0, 200));
  ok("the password reset email is on and locked", by["email.passenger.password_reset"]?.status === "active" && by["email.passenger.password_reset"]?.locked === true);
  ok("every other built-in starts off", rows.filter((r) => r.is_system && r.key !== "email.passenger.password_reset").every((r) => r.status === "inactive"));
  ok("connected events are marked, unconnected say so", by["email.passenger.ride_receipt"]?.connected === true && by["email.passenger.refund"]?.connected === false && /Not connected/.test(by["email.passenger.refund"]?.connection_note ?? ""));
  ok("all three audiences exist", ["passenger", "driver", "system"].every((a) => rows.some((r) => r.audience === a)));
  const again = await call("GET", "/admin/email-templates?limit=100&status=all", A);
  ok("opening the list again does not duplicate built-ins", again.json.total === list.json.total);
  const meta = await call("GET", "/admin/email-templates/meta", A);
  ok("meta lists variables, categories and branding", ["recipient_name", "code", "action_url", "ride_id", "fare"].every((n) => meta.json.variables?.some((v) => v.name === n)) && meta.json.categories?.length >= 10 && !!meta.json.brand?.brand_name);
  ok("sensitive variables are flagged", meta.json.variables.find((v) => v.name === "code")?.sensitive === true);

  // ---- the password reset template cannot be switched off or archived, and a later edit still sends
  const pr = by["email.passenger.password_reset"];
  ok("password reset cannot be switched off", (await call("POST", `/admin/email-templates/${pr.id}/status`, A, { status: "inactive" })).status === 409);
  ok("password reset cannot be archived", (await call("POST", `/admin/email-templates/${pr.id}/status`, A, { status: "archived" })).status === 409);
  ok("built-in templates cannot be deleted", (await call("DELETE", `/admin/email-templates/${pr.id}`, A)).status === 409);

  // ---- validation: the safe-HTML rules are enforced by the server
  const key = `email.passenger.smoke_${s}`;
  const bad = async (patch, text) => { const r = await call("POST", "/admin/email-templates", A, { ...base, key, ...patch }); return r.status === 422 && JSON.stringify(r.json).includes(text); };
  ok("a script tag is refused", await bad({ html_body: "<p>x</p><script>alert(1)</script>" }, "script"));
  ok("an event handler is refused", await bad({ html_body: "<p onclick=\"x()\">x</p>" }, "Event handlers"));
  ok("an iframe is refused", await bad({ html_body: "<iframe src=\"https://x.com\"></iframe>" }, "iframe"));
  ok("a javascript link is refused", await bad({ html_body: "<a href=\"javascript:alert(1)\">x</a>" }, "Links must"));
  ok("an http image is refused", await bad({ html_body: "<img src=\"http://x.com/a.png\" alt=\"a\">" }, "https"));
  ok("CSS that loads something is refused", await bad({ html_body: "<p style=\"background:url(https://x.com/a.png)\">x</p>" }, "not allowed"));
  ok("an unknown placeholder is refused", await bad({ html_body: "<p>{{secret}}</p>" }, "Unknown placeholder"));
  ok("an inherited name is refused", await bad({ text_body: "{{constructor}}" }, "Unknown placeholder"));
  ok("a text variable cannot be a link", await bad({ html_body: "<a href=\"{{recipient_name}}\">x</a>" }, "link placeholder"));
  ok("a code cannot be in the subject", await bad({ subject: "Your code {{code}}" }, "lock screens"));
  ok("a multi-line subject is refused", await bad({ subject: "a\nBcc: x@y.com" }, "one line"));
  ok("a bad key is refused", await bad({ key: "Bad Key" }, "key"));
  ok("an unknown category is refused", await bad({ category: "nope" }, "category"));
  ok("the plain-text version is required", await bad({ text_body: "" }, "text_body"));

  // ---- create, edit, version, audit
  const c1 = await call("POST", "/admin/email-templates", A, { ...base, key });
  ok("a valid template is created, switched off", c1.status === 201 && c1.json.data.status === "inactive" && c1.json.data.is_system === false && c1.json.data.version === 1, JSON.stringify(c1.json).slice(0, 200));
  ok("variables are derived by the server", JSON.stringify(c1.json.data?.variables?.slice().sort()) === JSON.stringify(["recipient_name", "ride_id"]));
  keys.push(key);
  const id = c1.json.data?.id;
  ok("a duplicate key is refused", (await call("POST", "/admin/email-templates", A, { ...base, key })).status === 422);
  const e1 = await call("PUT", `/admin/email-templates/${id}`, A, { ...base, key, subject: "Edited {{recipient_name}}", html_body: "<p>New text {{fare}}</p>", text_body: "New text {{fare}}" });
  ok("an edit saves and bumps the version", e1.status === 200 && e1.json.data.version === 2 && e1.json.data.subject.startsWith("Edited"), JSON.stringify(e1.json).slice(0, 200));
  const g1 = await call("GET", `/admin/email-templates/${id}`, A);
  ok("history keeps every version", g1.json.versions?.length === 2 && g1.json.versions[0].version === 2);
  ok("create and edit are audit-logged", (await db.query("select 1 from app.admin_audit where action = 'email_template_add' and target = $1", [String(id)])).rowCount === 1
    && (await db.query("select 1 from app.admin_audit where action = 'email_template_edit' and target = $1", [String(id)])).rowCount === 1);
  const rs = await call("POST", `/admin/email-templates/${id}/restore`, A, { version: 1 });
  ok("restoring puts old text back as a new version", rs.status === 200 && rs.json.data.version === 3 && rs.json.data.subject.startsWith("Hello") && (await call("GET", `/admin/email-templates/${id}`, A)).json.versions.length === 3);
  ok("restore is audit-logged", (await db.query("select 1 from app.admin_audit where action = 'email_template_restore' and target = $1", [String(id)])).rowCount === 1);
  ok("restoring a missing version is a 404", (await call("POST", `/admin/email-templates/${id}/restore`, A, { version: 99 })).status === 404);

  // ---- built-ins: text is editable, identity is not
  const sys = by["email.passenger.ride_receipt"];
  ok("a built-in's key and audience cannot change", (await call("PUT", `/admin/email-templates/${sys.id}`, A, { name: sys.name, category: sys.category, audience: "driver", subject: sys.subject, html_body: base.html_body, text_body: base.text_body })).status === 422);
  const sysEdit = await call("PUT", `/admin/email-templates/${sys.id}`, A, { name: sys.name, category: sys.category, audience: sys.audience, subject: "Receipt {{ride_id}}", html_body: "<p>Thanks {{recipient_name}}. Total {{fare}}</p>", text_body: "Thanks {{recipient_name}}. Total {{fare}}" });
  ok("a built-in's wording can be edited and stays off", sysEdit.status === 200 && sysEdit.json.data.status === "inactive" && sysEdit.json.data.is_system === true);
  ok("a second pass over the built-ins keeps the edit", (await call("GET", "/admin/email-templates?limit=100&status=all", A)).json.data.find((r) => r.key === sys.key).subject === "Receipt {{ride_id}}");

  // ---- preview: nothing is saved, light and dark differ, unsafe HTML never renders
  const pv = await call("POST", "/admin/email-templates/preview", A, { ...base, scheme: "light" });
  const pd = await call("POST", "/admin/email-templates/preview", A, { ...base, scheme: "dark" });
  ok("preview renders a branded, responsive email with sample values", pv.json.valid === true && pv.json.html.includes("prefers-color-scheme: dark") && pv.json.html.includes("name=\"viewport\"") && pv.json.subject === "Hello Amina" && /Hi Amina/.test(pv.json.text));
  ok("the dark preview differs from the light one", pd.json.valid === true && pd.json.html !== pv.json.html && pd.json.html.includes("#121212"));
  const pbad = await call("POST", "/admin/email-templates/preview", A, { ...base, html_body: "<script>alert(1)</script>" });
  ok("an unsafe preview returns the problem and no HTML", pbad.json.valid === false && pbad.json.html === null && JSON.stringify(pbad.json.errors).includes("script"));
  const pesc = await call("POST", "/admin/email-templates/preview", A, { ...base, values: { recipient_name: "<script>alert(1)</script>" } });
  ok("values are escaped in the preview", !pesc.json.html.includes("<script>alert(1)") && pesc.json.html.includes("&lt;script&gt;"));

  // ---- duplicate, archive, restore, search and filters
  const dup = await call("POST", `/admin/email-templates/${id}/duplicate`, A);
  ok("a template can be duplicated (off, custom, new key)", dup.status === 201 && dup.json.data.status === "inactive" && dup.json.data.is_system === false && dup.json.data.key !== key, JSON.stringify(dup.json).slice(0, 200));
  keys.push(dup.json.data?.key);
  ok("archiving hides it from the default list", (await call("POST", `/admin/email-templates/${dup.json.data.id}/status`, A, { status: "archived" })).status === 200
    && !(await call("GET", "/admin/email-templates?limit=100", A)).json.data.some((r) => r.id === dup.json.data.id));
  ok("archived templates show when asked", (await call("GET", "/admin/email-templates?status=archived&limit=100", A)).json.data.some((r) => r.id === dup.json.data.id));
  ok("search finds by wording", (await call("GET", `/admin/email-templates?q=${encodeURIComponent("Hello")}&limit=100&status=all`, A)).json.data.some((r) => r.id === id));
  ok("filters by audience and category work", (await call("GET", "/admin/email-templates?audience=driver&limit=100&status=all", A)).json.data.every((r) => r.audience === "driver")
    && (await call("GET", "/admin/email-templates?category=documents&limit=100&status=all", A)).json.data.every((r) => r.category === "documents"));
  ok("switching on and off works and is audit-logged", (await call("POST", `/admin/email-templates/${id}/status`, A, { status: "active" })).json.status === "active"
    && (await db.query("select 1 from app.admin_audit where action = 'email_template_status' and target = $1", [String(id)])).rowCount >= 1);
  ok("an active template cannot be deleted", (await call("DELETE", `/admin/email-templates/${id}`, A)).status === 409);
  await call("POST", `/admin/email-templates/${id}/status`, A, { status: "inactive" });

  // ---- branding
  ok("a bad accent colour is refused", (await call("PUT", "/admin/email-branding", A, { brand_name: "DROP", accent: "orange" })).status === 422);
  ok("a non-https logo is refused", (await call("PUT", "/admin/email-branding", A, { brand_name: "DROP", logo_url: "http://x.com/a.png" })).status === 422);
  const br = await call("PUT", "/admin/email-branding", A, { brand_name: "DROP Smoke", accent: "#0b7a4b", footer_note: "Smoke footer", support_email: "help@example.com", logo_url: null, address: "" });
  ok("branding saves", br.status === 200 && br.json.data.accent === "#0B7A4B" && br.json.data.brand_name === "DROP Smoke");
  const brPreview = await call("POST", "/admin/email-templates/preview", A, { ...base });
  ok("branding shows in the next email", brPreview.json.html.includes("#0B7A4B") && brPreview.json.html.includes("Smoke footer") && brPreview.json.html.includes("help@example.com"));
  ok("branding changes are audit-logged", (await db.query("select 1 from app.admin_audit where action = 'email_branding_edit'")).rowCount >= 1);
  await call("PUT", "/admin/email-branding", A, { brand_name: "DROP", accent: "#FF8A00", footer_note: "You are receiving this email because of activity on your DROP account.", support_email: "", logo_url: null, address: "" });

  // ---- test send: only to a DROP account; failure is logged and explained
  ok("a test to an address with no account is refused", (await call("POST", `/admin/email-templates/${id}/test`, A, { email: `nobody${s}@example.invalid` })).status === 404);
  const ts = await call("POST", `/admin/email-templates/${id}/test`, A, { email: P.email ?? `em${s}@x.com` });
  ok("a test send reports a provider that is not set up", ts.status === 502 && /not set up/i.test(ts.json.message ?? ""), JSON.stringify(ts.json));
  const dt = (await db.query("select * from app.email_deliveries where user_id = $1 and template_key = $2 and is_test", [P.id, key])).rows[0];
  ok("the test send is logged as a test by the admin, with the rendered body", !!dt && dt.sent_by != null && dt.status === "failed" && /Hello/.test(dt.subject) && /Hi /.test(dt.html_body ?? ""));

  // ---- delivery log, inspection, statistics
  const log = await call("GET", "/admin/email-deliveries?limit=100", A);
  ok("the log hides tests by default", log.status === 200 && !log.json.data.some((r) => r.is_test));
  ok("the log shows tests when asked", (await call("GET", "/admin/email-deliveries?tests=only&limit=100", A)).json.data.some((r) => r.id === dt.id));
  ok("the log filters by result, template and recipient", (await call("GET", "/admin/email-deliveries?status=failed&template_key=email.passenger.password_reset&limit=100", A)).json.data.every((r) => r.status === "failed" && r.template_key === "email.passenger.password_reset")
    && (await call("GET", `/admin/email-deliveries?q=${encodeURIComponent("em" + s)}&tests=include&limit=100`, A)).json.data.length >= 1);
  const det = await call("GET", `/admin/email-deliveries/${d0.id}`, A);
  ok("a failure can be inspected: reason, explanation, no body for a code email", det.status === 200 && !!det.json.data.reason && /not retry/i.test(det.json.explanation ?? "") && /not kept/i.test(det.json.body_note ?? "") && det.json.data.html_body === null);
  const det2 = await call("GET", `/admin/email-deliveries/${dt.id}`, A);
  ok("a normal email keeps its body for inspection", det2.json.data.html_body?.includes("<html") && det2.json.body_note === null);
  const st = await call("GET", "/admin/email-deliveries/stats?days=7", A);
  ok("statistics load and exclude tests", st.status === 200 && st.json.totals.failed >= 1 && Array.isArray(st.json.by_template) && Array.isArray(st.json.reasons));

  // ---- duplicate prevention lives in the database
  const dk = `smoke.dedupe.${s}`;
  const ins = (n) => db.query("insert into app.email_deliveries (template_key, to_email, subject, status, idempotency_key, dedupe_key, dedupe_bucket) values ($1,'a@x.com','s','sent',gen_random_uuid(),$2,12345) on conflict do nothing returning id", [`smoke.${s}`, dk]);
  ok("the same email in the same window is stored once", (await ins(1)).rowCount === 1 && (await ins(2)).rowCount === 0);
  ok("a different window is allowed", (await db.query("insert into app.email_deliveries (template_key, to_email, subject, status, idempotency_key, dedupe_key, dedupe_bucket) values ($1,'a@x.com','s','sent',gen_random_uuid(),$2,12346) returning id", [`smoke.${s}`, dk])).rowCount === 1);
  ok("the retry index exists", (await db.query("select 1 from pg_indexes where schemaname = 'app' and indexname = 'email_deliveries_retry_idx'")).rowCount === 1);

  // ---- delete a custom template; its history stays
  ok("a switched-off custom template can be deleted", (await call("DELETE", `/admin/email-templates/${id}`, A)).status === 200 && (await call("GET", `/admin/email-templates/${id}`, A)).status === 404);
  ok("its delivery history is kept", (await db.query("select 1 from app.email_deliveries where template_key = $1", [key])).rowCount >= 1);
  ok("deletion is audit-logged", (await db.query("select 1 from app.admin_audit where action = 'email_template_delete' and target = $1", [String(id)])).rowCount === 1);

  // ---- a provider that refuses (invalid key): the failure is logged with the provider's status and never breaks the request
  const gw = await call("PUT", "/admin/payment-gateways/resend", A, { is_test: false, status: true, credentials: { live: { api_key: "re_ci_invalid_key_" + s, from_email: "DROP <ci@example.com>" } } });
  resendConfigured = gw.status === 200;
  ok("the email provider can be configured through Admin", resendConfigured, JSON.stringify(gw.json));
  if (resendConfigured) {
    const fp2 = await call("POST", "/forgot-password", null, { identifier: Q.email ?? `eq${s}@x.com` });
    ok("a refused email never breaks password reset", fp2.status === 200, JSON.stringify(fp2.json));
    const d1 = (await db.query("select * from app.email_deliveries where user_id = $1 and template_key = 'email.passenger.password_reset' order by id desc limit 1", [Q.id])).rows[0];
    ok("the refusal is logged, with the provider's status when it answered", !!d1 && d1.status === "failed" && !!d1.reason && d1.attempts === 1 && d1.html_body === null, JSON.stringify(d1 ?? {}).slice(0, 250));
    ok("a refusal that cannot clear is not retried; a code email never is", !!d1 && d1.retryable === false && d1.next_retry_at === null);
    const t2 = await call("POST", `/admin/email-templates/${by["email.passenger.ride_receipt"].id}/test`, A, { email: Q.email ?? `eq${s}@x.com` });
    ok("a test send through a refusing provider reports the provider's answer", t2.status === 502 && /Resend|fetch|network/i.test(t2.json.message ?? ""), JSON.stringify(t2.json));
    const d2 = (await db.query("select * from app.email_deliveries where user_id = $1 and template_key = 'email.passenger.ride_receipt' and is_test order by id desc limit 1", [Q.id])).rows[0];
    ok("the retry decision follows the provider's status (4xx never, network or 5xx may)", !!d2 && d2.status === "failed" && (d2.provider_status >= 400 && d2.provider_status < 500 && d2.provider_status !== 429 ? d2.retryable === false : true) && (d2.retryable ? d2.next_retry_at !== null : d2.next_retry_at === null));
  }
} finally {
  await db.query("delete from app.email_deliveries where user_id = any($1) or template_key like $2 or template_key = $3", [users.filter(Boolean), `smoke.${s}`, `email.passenger.smoke_${s}`]).catch(() => {});
  await db.query("delete from app.email_templates where key = any($1) or key like $2", [keys.filter(Boolean), `%smoke_${s}%`]).catch(() => {});
  if (resendConfigured) {
    await db.query("delete from app.gateway_credentials where gateway_type = 'resend'").catch(() => {});
    await db.query("update app.payment_gateways set status = false where type = 'resend'").catch(() => {});
  }
  for (const id of users) await db.query("delete from app.users where id = $1", [id]).catch(() => {});
}
console.log(fails ? `${fails} FAILED` : "ALL PASSED");
await db.end(); process.exit(fails ? 1 : 0);
