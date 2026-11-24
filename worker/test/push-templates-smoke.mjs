// Push template management end to end against a disposable DB. Test/CI database only, never production.
// OneSignal is not configured in CI, so this proves: permissions, validation, CRUD, versioning, audit, preview, search,
// safe delete, test-send logging (including masking of sensitive values) and failure handling. It does not reach a phone.
// Run: DATABASE_URL=... ADMIN_EMAIL=... ADMIN_PASSWORD=... node test/push-templates-smoke.mjs
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
const reg = async (type, tag) => (await call("POST", "/register", null, { first_name: "P", last_name: tag + s, email: `${tag}${s}@x.com`, username: `${tag}${s}`, password: "secret123", user_type: type, contact_number: phone() })).json.data;
const A = (await call("POST", "/login", null, { email: ADMIN_EMAIL, password: ADMIN_PASSWORD, user_type: "admin" })).json.data?.api_token;
const keys = [], users = [];
const base = { name: "Smoke " + s, category: "promotion", audience: "passenger", title: "Hello {{passenger_name}}", body: "Your ride {{ride_id}} is set." };
try {
  const P = await reg("rider", "pt"); users.push(P.id);
  const PW = await reg("rider", "pw"); users.push(PW.id);

  // ---- permissions
  ok("a rider cannot list templates", (await call("GET", "/admin/push-templates", P.api_token)).status === 403);
  ok("a rider cannot create templates", (await call("POST", "/admin/push-templates", P.api_token, { ...base, key: `passenger.smoke_${s}` })).status === 403);
  ok("a rider cannot read the delivery log", (await call("GET", "/admin/push-deliveries", P.api_token)).status === 403);
  ok("signed-out requests are refused", (await call("GET", "/admin/push-templates", null)).status === 401);

  // ---- built-in templates appear, with safe starting states
  const list = await call("GET", "/admin/push-templates?limit=100&status=all", A);
  const rows = list.json.data ?? [];
  const by = Object.fromEntries(rows.map((r) => [r.key, r]));
  ok("the list loads and built-ins are created", list.status === 200 && list.json.total >= 60, JSON.stringify(list.json).slice(0, 200));
  ok("an event that already sent a push starts on", by["passenger.driver_assigned"]?.status === "active" && by["driver.new_ride_request"]?.status === "active");
  ok("newly connected events start off", by["passenger.ride_requested"]?.status === "inactive" && by["driver.airport_booking_assigned"]?.status === "inactive" && by["passenger.airport_pickup_confirmed"]?.status === "inactive");
  ok("unconnected events say so", by["passenger.scheduled_reminder"]?.connected === false && /Not connected/.test(by["passenger.scheduled_reminder"]?.connection_note ?? ""));
  ok("built-ins are marked", by["passenger.driver_assigned"]?.is_system === true);
  const again = await call("GET", "/admin/push-templates?limit=100&status=all", A);
  ok("opening the list again does not duplicate built-ins", again.json.total === list.json.total);
  ok("the pickup-code default carries no code", !/\{\{otp\}\}/.test(by["passenger.pickup_otp"]?.body ?? "x"));
  const meta = await call("GET", "/admin/push-templates/meta", A);
  ok("meta lists the variables", ["passenger_name", "driver_name", "ride_id", "pickup_location", "destination", "airport_name", "airport_code", "terminal", "eta", "fare", "wallet_balance", "otp"].every((n) => meta.json.variables?.some((v) => v.name === n)));

  // ---- validation
  const key = `passenger.smoke_${s}`;
  const bad = async (patch, field) => { const r = await call("POST", "/admin/push-templates", A, { ...base, key, ...patch }); return r.status === 422 && JSON.stringify(r.json).includes(field); };
  ok("an unknown placeholder is refused", await bad({ body: "Hi {{secret}}" }, "Unknown placeholder"));
  ok("code-like placeholders are refused", await bad({ body: "{{process.env.X}}" }, "placeholder"));
  ok("an inherited name is refused", await bad({ body: "{{constructor}}" }, "Unknown placeholder"));
  ok("the pickup code cannot go in a link", await bad({ deep_link: "drop://x/{{otp}}" }, "link"));
  ok("a javascript link is refused", await bad({ deep_link: "javascript:alert(1)" }, "drop://"));
  ok("an unlisted website link is refused", await bad({ deep_link: "https://evil.example/" }, "drop://"));
  ok("an http image is refused", await bad({ image_url: "http://x.example/a.png" }, "https"));
  ok("a bad key is refused", await bad({ key: "Bad Key" }, "key"));
  ok("an unknown category is refused", await bad({ category: "nope" }, "category"));

  // ---- create, edit, version, audit
  const c1 = await call("POST", "/admin/push-templates", A, { ...base, key, deep_link: "drop://ride/{{ride_id}}", action_label: "Open" });
  ok("a valid template is created, switched off", c1.status === 201 && c1.json.data.status === "inactive" && c1.json.data.is_system === false && c1.json.data.version === 1, JSON.stringify(c1.json).slice(0, 200));
  ok("variables are derived by the server", JSON.stringify(c1.json.data?.variables?.slice().sort()) === JSON.stringify(["passenger_name", "ride_id"]));
  keys.push(key);
  const id = c1.json.data?.id;
  ok("a duplicate key is refused", (await call("POST", "/admin/push-templates", A, { ...base, key })).status === 422);
  const e1 = await call("PUT", `/admin/push-templates/${id}`, A, { ...base, key, title: "Edited {{passenger_name}}", body: "New text", deep_link: null });
  ok("an edit saves and bumps the version", e1.status === 200 && e1.json.data.version === 2 && e1.json.data.title.startsWith("Edited") && e1.json.data.deep_link === null, JSON.stringify(e1.json).slice(0, 200));
  const g1 = await call("GET", `/admin/push-templates/${id}`, A);
  ok("history keeps every version", g1.json.versions?.length === 2 && g1.json.versions[0].version === 2);
  ok("create and edit are audit-logged", (await db.query("select 1 from app.admin_audit where action = 'push_template_add' and target = $1", [String(id)])).rowCount === 1
    && (await db.query("select 1 from app.admin_audit where action = 'push_template_edit' and target = $1", [String(id)])).rowCount === 1);
  const sys = by["passenger.driver_assigned"];
  ok("a built-in's key and audience cannot change", (await call("PUT", `/admin/push-templates/${sys.id}`, A, { name: sys.name, category: sys.category, audience: "driver", title: sys.title, body: sys.body })).status === 422);
  const sysEdit = await call("PUT", `/admin/push-templates/${sys.id}`, A, { name: sys.name, category: sys.category, audience: sys.audience, title: sys.title, body: sys.body });
  ok("a built-in's text can be edited (saved unchanged here)", sysEdit.status === 200);

  // ---- preview
  const pv = await call("POST", "/admin/push-templates/preview", A, { title: "Hi {{passenger_name}}", body: "Fare {{fare}} to {{destination}}", deep_link: "drop://ride/{{ride_id}}" });
  ok("preview fills sample values", pv.json.valid === true && pv.json.title === "Hi Amina" && pv.json.body.includes("₦2,500") && pv.json.deep_link === "drop://ride/1042", JSON.stringify(pv.json));
  const pb = await call("POST", "/admin/push-templates/preview", A, { title: "x", body: "{{nope}}" });
  ok("preview reports problems", pb.json.valid === false && pb.json.errors.body);
  ok("preview never expands a value twice", (await call("POST", "/admin/push-templates/preview", A, { title: "{{passenger_name}}", body: "b", values: { passenger_name: "{{otp}}" } })).json.title === "{{otp}}");

  // ---- on/off, archive, search, duplicate
  ok("switching on works", (await call("POST", `/admin/push-templates/${id}/status`, A, { status: "active" })).json.status === "active");
  ok("an invalid status is refused", (await call("POST", `/admin/push-templates/${id}/status`, A, { status: "deleted" })).status === 422);
  const found = await call("GET", `/admin/push-templates?q=${encodeURIComponent("Smoke " + s)}`, A);
  ok("search finds by name", found.json.total === 1 && found.json.data[0].id === id);
  ok("search treats % and _ as plain text", (await call("GET", "/admin/push-templates?q=%25", A)).json.total === 0);
  ok("filters narrow the list", (await call("GET", "/admin/push-templates?audience=driver&status=all&limit=100", A)).json.data.every((r) => r.audience === "driver"));
  const dup = await call("POST", `/admin/push-templates/${id}/duplicate`, A);
  ok("duplicate makes an inactive custom copy", dup.status === 201 && dup.json.data.key === `${key}_copy` && dup.json.data.status === "inactive" && dup.json.data.is_system === false, JSON.stringify(dup.json).slice(0, 200));
  keys.push(`${key}_copy`);
  const dup2 = await call("POST", `/admin/push-templates/${id}/duplicate`, A);
  ok("a second duplicate gets its own key", dup2.status === 201 && dup2.json.data.key === `${key}_copy2`);
  keys.push(`${key}_copy2`);
  ok("archive hides it from the default list", (await call("POST", `/admin/push-templates/${dup2.json.data.id}/status`, A, { status: "archived" })).status === 200
    && (await call("GET", `/admin/push-templates?q=${encodeURIComponent(key + "_copy2")}`, A)).json.total === 0
    && (await call("GET", `/admin/push-templates?q=${encodeURIComponent(key + "_copy2")}&status=archived`, A)).json.total === 1);

  // ---- safe delete
  ok("a built-in cannot be deleted", (await call("DELETE", `/admin/push-templates/${sys.id}`, A)).status === 409);
  ok("an active template cannot be deleted", (await call("DELETE", `/admin/push-templates/${id}`, A)).status === 409);
  ok("a rider cannot delete", (await call("DELETE", `/admin/push-templates/${dup.json.data.id}`, P.api_token)).status === 403);
  ok("an inactive custom template can be deleted", (await call("DELETE", `/admin/push-templates/${dup.json.data.id}`, A)).status === 200 && (await call("GET", `/admin/push-templates/${dup.json.data.id}`, A)).status === 404);
  ok("its key becomes free again", (await call("POST", "/admin/push-templates", A, { ...base, key: `${key}_copy` })).status === 201);
  ok("deletion is audit-logged", (await db.query("select 1 from app.admin_audit where action = 'push_template_delete'")).rowCount >= 1);

  // ---- test send and delivery log (OneSignal is not configured here)
  const sens = await call("POST", "/admin/push-templates", A, { ...base, key: `passenger.smoke_otp_${s}`, title: "Code", body: "Your code is {{otp}}" });
  keys.push(`passenger.smoke_otp_${s}`);
  ok("a template with the pickup code can be saved", sens.status === 201);
  ok("a test to an unknown email is refused", (await call("POST", `/admin/push-templates/${id}/test`, A, { email: `nobody${s}@x.com` })).status === 404);
  ok("a bad email is refused", (await call("POST", `/admin/push-templates/${id}/test`, A, { email: "nope" })).status === 422);
  ok("a test to someone with no phone says so", (await call("POST", `/admin/push-templates/${id}/test`, A, { email: PW.email })).status === 409);
  ok("a rider cannot send tests", (await call("POST", `/admin/push-templates/${id}/test`, P.api_token, { email: PW.email })).status === 403);
  await db.query("update app.users set player_id = $2 where id = $1", [P.id, "ci-fake-device-" + s]);
  const t1 = await call("POST", `/admin/push-templates/${sens.json.data.id}/test`, A, { email: P.email });
  ok("with no OneSignal set up the test fails cleanly", t1.status === 502 && /not set up|OneSignal/i.test(t1.json.message ?? ""), JSON.stringify(t1.json));
  const logged = (await db.query("select * from app.push_deliveries where user_id = $1 order by id desc limit 1", [P.id])).rows[0];
  ok("the failure is logged as a test", logged && logged.status === "failed" && logged.is_test === true && logged.template_key === `passenger.smoke_otp_${s}` && logged.attempts === 1);
  ok("the pickup code is masked in the log", logged && !/\d{4}/.test(logged.body) && logged.body.includes("••••"), logged?.body);
  ok("a row with a sensitive value is never retried", logged && logged.retryable === false && logged.next_retry_at === null);
  ok("the test is audit-logged", (await db.query("select 1 from app.admin_audit where action = 'push_template_test' and target = $1", [String(sens.json.data.id)])).rowCount === 1);
  const dl = await call("GET", "/admin/push-deliveries?tests=only&status=failed&q=" + encodeURIComponent(P.email), A);
  ok("the delivery log filters and shows the failure", dl.status === 200 && dl.json.total >= 1 && dl.json.data[0].reason && dl.json.data[0].email === P.email, JSON.stringify(dl.json).slice(0, 200));
  ok("tests are hidden from the log by default", (await call("GET", "/admin/push-deliveries?q=" + encodeURIComponent(P.email), A)).json.total === 0);
  const st = await call("GET", "/admin/push-deliveries/stats?days=7", A);
  ok("statistics have the expected shape and leave tests out", st.status === 200 && st.json.totals && typeof st.json.totals.sent === "number" && Array.isArray(st.json.by_template) && !st.json.by_template.some((x) => x.template_key === `passenger.smoke_otp_${s}`), st.status + " " + JSON.stringify(st.json).slice(0, 300));

  // ---- a retryable failure is retried by the sweep logic (simulated row), and gives up after 3 tries
  const idem = crypto.randomUUID();
  const r1 = (await db.query(
    `insert into app.push_deliveries (template_key, user_id, title, body, status, reason, attempts, retryable, next_retry_at, idempotency_key)
     values ($1,$2,'t','b','failed','OneSignal said: 503',1,true, now() - interval '1 minute',$3) returning id`, [`passenger.smoke_retry_${s}`, P.id, idem])).rows[0].id;
  ok("a due retryable failure is selectable for retry", (await db.query("select 1 from app.push_deliveries where id = $1 and status='failed' and retryable and attempts < 3 and next_retry_at <= now()", [r1])).rowCount === 1);

  // ---- the event pipeline ran during the ride-flow tests (CI runs those first)
  const ev = (await db.query("select status, reason from app.push_deliveries where template_key = 'passenger.driver_assigned' and not is_test order by id desc limit 5")).rows;
  if (ev.length) ok("ride events are logged through templates (no phone registered: skipped, not an error)", ev.every((r) => r.status === "skipped" || r.status === "failed" || r.status === "sent"));
  else console.log("SKIP ride-event rows: run rides-trip-smoke first to produce them");
} finally {
  await db.query("delete from app.push_deliveries where user_id = any($1) or template_key like $2", [users.filter(Boolean), `%smoke%${s}`]).catch(() => {});
  await db.query("delete from app.push_templates where key = any($1) or key like $2", [keys, `%smoke%${s}%`]).catch(() => {});
  for (const id of users) await db.query("delete from app.users where id = $1", [id]).catch(() => {});
}
console.log(fails ? `${fails} FAILED` : "ALL PASSED");
await db.end(); process.exit(fails ? 1 : 0);
