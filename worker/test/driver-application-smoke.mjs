// Driver application flow against a running `wrangler dev -c wrangler.test.jsonc` (local R2) and a LOCAL/test database.
// Run: DATABASE_URL=... ADMIN_EMAIL=... ADMIN_PASSWORD=... node test/driver-application-smoke.mjs
import pg from "pg";
const API = (process.env.BASE ?? "http://127.0.0.1:8787") + "/api";
const { ADMIN_EMAIL, ADMIN_PASSWORD, DATABASE_URL } = process.env;
if (!ADMIN_EMAIL || !ADMIN_PASSWORD || !DATABASE_URL) throw new Error("set ADMIN_EMAIL, ADMIN_PASSWORD and DATABASE_URL");
const db = new pg.Client({ connectionString: DATABASE_URL }); await db.connect();
let fails = 0;
const ok = (n, c, extra = "") => { console.log(c ? "PASS" : "FAIL", n, c ? "" : extra); if (!c) fails++; };
const call = async (method, path, token, body, raw) => {
  const headers = { Accept: "application/json", ...(token ? { Authorization: "Bearer " + token } : {}) };
  let payload;
  if (raw) payload = raw; else if (body) { headers["Content-Type"] = "application/json"; payload = JSON.stringify(body); }
  const r = await fetch(API + path, { method, headers, body: payload });
  const ct = r.headers.get("content-type") ?? "";
  return { status: r.status, headers: r.headers, json: ct.includes("json") ? await r.json().catch(() => ({})) : {}, bytes: ct.includes("json") ? null : new Uint8Array(await r.arrayBuffer()) };
};
await db.query("delete from app.documents where name ~ '^(Licence|Papers|Extra|Bike)[a-z0-9]{5,6}$'");
const s = Math.random().toString(36).slice(2, 8);
const PNG = new Uint8Array([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0, 0, 0, 0]);
const PDF = new TextEncoder().encode("%PDF-1.4\n%test");
const future = new Date(Date.now() + 400 * 864e5).toISOString().slice(0, 10);

const A = (await call("POST", "/login", null, { email: ADMIN_EMAIL, password: ADMIN_PASSWORD, user_type: "admin" })).json.data?.api_token;
const region = (await db.query("insert into app.regions (name, distance_unit, timezone, status) values ($1,'km','Africa/Lagos',true) returning id", ["R" + s])).rows[0].id * 1;
const svc = (await db.query("insert into app.services (name, region_id, capacity, base_fare, commission_type, admin_commission, payment_method, status) values ($1,$2,4,0,'percentage',10,'cash_wallet',true) returning id", ["Car" + s, region])).rows[0].id * 1;
const docLic = (await db.query("insert into app.documents (name, type, is_required, has_expiry_date, status) values ($1,'driver',true,true,true) returning id", ["Licence" + s])).rows[0].id * 1;
const docPap = (await db.query("insert into app.documents (name, type, is_required, has_expiry_date, status) values ($1,'driver',true,false,true) returning id", ["Papers" + s])).rows[0].id * 1;
const docOpt = (await db.query("insert into app.documents (name, type, is_required, has_expiry_date, status) values ($1,'driver',false,false,true) returning id", ["Extra" + s])).rows[0].id * 1;
const docOther = (await db.query("insert into app.documents (name, type, is_required, status) values ($1,'driver',true,true) returning id", ["Bike" + s])).rows[0].id * 1;
const otherSvc = (await db.query("insert into app.services (name, region_id, capacity, base_fare, commission_type, admin_commission, payment_method, status) values ($1,$2,2,0,'percentage',10,'cash_wallet',true) returning id", ["Bike" + s, region])).rows[0].id * 1;
await db.query("insert into app.document_requirements (document_id, service_id) values ($1,$2)", [docOther, otherSvc]);

const reg = async (tag) => (await call("POST", "/register", null, { first_name: "Ada", last_name: tag + s, email: `${tag}${s}@x.com`, username: `${tag}${s}`, password: "secret123", user_type: "rider", contact_number: "0803" + Math.floor(1000000 + Math.random() * 8999999) })).json.data;
const R = await reg("app"), O = await reg("oth");
const T = R.api_token;

// requirements
const rq = (await call("GET", "/driver/requirements", T)).json;
ok("requirements: rules, vehicle types, documents", rq.min_age === 19 && rq.vehicles.some((v) => v.id === svc) && rq.documents.some((d) => d.id === docLic && d.has_expiry_date), JSON.stringify(rq).slice(0, 200));
ok("admin cannot use the applicant API", (await call("GET", "/driver/requirements", A)).status === 403);
ok("starts as not_started", (await call("GET", "/driver/application", T)).json.status === "not_started");

// personal
const young = new Date(Date.now() - 15 * 365 * 864e5).toISOString().slice(0, 10);
ok("under the minimum age refused", (await call("PUT", "/driver/application/personal", T, { first_name: "Ada", last_name: "Obi", date_of_birth: young })).status === 422);
ok("bad date refused", (await call("PUT", "/driver/application/personal", T, { first_name: "Ada", last_name: "Obi", date_of_birth: "31/12/1990" })).status === 422);
ok("personal saved", (await call("PUT", "/driver/application/personal", T, { first_name: "Ada", last_name: "Obi", date_of_birth: "1990-05-17" })).status === 200);
const st = (await call("GET", "/driver/application", T)).json;
ok("status draft, DOB stored", st.status === "draft" && st.personal.date_of_birth === "1990-05-17", JSON.stringify(st));
ok("person now has the driver role (not approved)", (await db.query("select roles from app.users where id = $1", [R.id])).rows[0].roles.includes("driver"));

// vehicle
const veh = { service_id: svc, licence_years: 5, make: "Toyota", model: "Corolla", colour: "Silver", year: "2015", plate: "abc123xy", seats: 4 };
ok("unknown vehicle type refused", (await call("PUT", "/driver/application/vehicle", T, { ...veh, service_id: 999999 })).status === 422);
ok("too many seats refused", (await call("PUT", "/driver/application/vehicle", T, { ...veh, seats: 9 })).status === 422);
ok("bad year refused", (await call("PUT", "/driver/application/vehicle", T, { ...veh, year: "15" })).status === 422);
ok("vehicle saved", (await call("PUT", "/driver/application/vehicle", T, veh)).status === 200);
ok("plate stored upper-case", (await db.query("select vehicle_plate from app.driver_profiles where user_id = $1", [R.id])).rows[0].vehicle_plate === "ABC123XY");

// uploads
ok("text file refused as a photo", (await call("PUT", "/driver/application/photo", T, null, new TextEncoder().encode("hello world, not an image"))).status === 415);
ok("renamed script refused (type judged by content)", (await call("PUT", `/driver/documents/${docPap}`, T, null, new TextEncoder().encode("<script>alert(1)</script>"))).status === 415);
ok("empty upload refused", (await call("PUT", `/driver/documents/${docPap}`, T, null, new Uint8Array(0))).status === 422);
ok("oversize refused", (await call("PUT", `/driver/documents/${docPap}`, T, null, new Uint8Array(5 * 1024 * 1024 + 10).fill(1))).status === 413);
ok("PDF photo refused", (await call("PUT", "/driver/application/photo", T, null, PDF)).status === 415);
ok("expiring document needs a future expiry date", (await call("PUT", `/driver/documents/${docLic}`, T, null, PNG)).status === 422);
ok("past expiry refused", (await call("PUT", `/driver/documents/${docLic}?expire_date=2020-01-01`, T, null, PNG)).status === 422);
ok("unknown document 404", (await call("PUT", "/driver/documents/999999", T, null, PNG)).status === 404);

// submit incomplete
const inc = await call("POST", "/driver/application/submit", T);
ok("incomplete submit lists what is missing", inc.status === 422 && inc.json.missing.includes("photo") && inc.json.missing.includes(`document:${docPap}`) && !inc.json.missing.includes(`document:${docOpt}`) && !inc.json.missing.includes(`document:${docOther}`), JSON.stringify(inc.json));

ok("photo saved", (await call("PUT", "/driver/application/photo", T, null, PNG)).status === 200);
ok("licence saved", (await call("PUT", `/driver/documents/${docLic}?expire_date=${future}`, T, null, PNG)).status === 200);
ok("papers saved (PDF)", (await call("PUT", `/driver/documents/${docPap}`, T, null, PDF)).status === 200);
const mine = await call("GET", `/driver/documents/${docPap}/file`, T);
ok("owner can preview own file, not cached, not sniffable", mine.status === 200 && mine.headers.get("content-type") === "application/pdf" && mine.headers.get("cache-control").includes("no-store") && mine.headers.get("x-content-type-options") === "nosniff");
ok("another rider cannot read it", (await call("GET", `/driver/documents/${docPap}/file`, O.api_token)).status === 404);
ok("submit works", (await call("POST", "/driver/application/submit", T)).status === 200);
ok("now submitted and locked", (await call("GET", "/driver/application", T)).json.editable === false);
ok("locked: personal edit refused", (await call("PUT", "/driver/application/personal", T, { first_name: "Ada", last_name: "Obi", date_of_birth: "1990-05-17" })).status === 409);
ok("locked: upload refused", (await call("PUT", `/driver/documents/${docPap}`, T, null, PDF)).status === 409);
ok("submitted application cannot enter driver mode", (await call("POST", "/mode", T, { mode: "driver" })).json.code === "not_approved");

// admin review
const q = (await call("GET", `/admin/driver-applications?q=app${s}`, A)).json;
ok("admin sees it in the queue", q.data.length === 1 && q.data[0].status === "submitted" && q.data[0].ride_type === "Car" + s, JSON.stringify(q));
const det = (await call("GET", `/admin/driver-applications/${R.id}`, A)).json.data;
ok("detail has profile and documents, no secrets", det.vehicle_plate === "ABC123XY" && det.documents.length === 3 && !("password_hash" in det));
const af = await call("GET", `/admin/driver-applications/${R.id}/documents/${docLic}/file`, A);
ok("admin can open an uploaded file", af.status === 200 && af.headers.get("content-type") === "image/png");
ok("admin can open the photo", (await call("GET", `/admin/driver-applications/${R.id}/photo`, A)).status === 200);
ok("applicant cannot use admin endpoints", (await call("GET", `/admin/driver-applications/${R.id}`, T)).status === 403);

let rv = await call("POST", `/admin/driver-applications/${R.id}/review`, A, { action: "approve" });
ok("approve blocked until documents are approved", rv.status === 409 && rv.json.code === "documents_not_approved" && rv.json.missing.length === 2, JSON.stringify(rv.json));
ok("reject needs a reason", (await call("POST", `/admin/driver-applications/${R.id}/review`, A, { action: "reject" })).status === 422);
ok("start review", (await call("POST", `/admin/driver-applications/${R.id}/review`, A, { action: "start_review" })).json.status === "in_review");
ok("document rejection needs a note", (await call("PUT", `/admin/driver-applications/${R.id}/documents/${docLic}`, A, { status: "rejected" })).status === 422);
ok("reject the licence photo with a note", (await call("PUT", `/admin/driver-applications/${R.id}/documents/${docLic}`, A, { status: "rejected", note: "Photo is blurry" })).status === 200);
ok("approve the papers", (await call("PUT", `/admin/driver-applications/${R.id}/documents/${docPap}`, A, { status: "approved" })).status === 200);
ok("ask for changes", (await call("POST", `/admin/driver-applications/${R.id}/review`, A, { action: "needs_changes", note: "Re-upload your licence" })).json.status === "needs_changes");
const back = (await call("GET", "/driver/application", T)).json;
ok("applicant sees the note and the document note, and can edit", back.status === "needs_changes" && back.editable && back.review_note === "Re-upload your licence" && back.documents.find((d) => d.document_id === docLic).note === "Photo is blurry" && back.documents.find((d) => d.document_id === docPap).status === "approved", JSON.stringify(back));
ok("re-upload licence", (await call("PUT", `/driver/documents/${docLic}?expire_date=${future}`, T, null, PNG)).status === 200);
ok("re-upload resets that document to pending", (await call("GET", "/driver/application", T)).json.documents.find((d) => d.document_id === docLic).status === "pending");
ok("resubmit", (await call("POST", "/driver/application/submit", T)).status === 200);

// a limited admin may look but not decide
const role = await call("POST", "/admin/roles", A, { name: "da" + s, label: "DA viewer", permissions: ["driver_application list"] });
await call("POST", "/admin/sub-admins", A, { first_name: "Vi", last_name: "Ewer", email: `v${s}@x.com`, username: `v${s}`, contact_number: null, admin_role_id: role.json.id, status: "active", password: "viewer-pass-123" });
const V = (await call("POST", "/login", null, { email: `v${s}@x.com`, password: "viewer-pass-123", user_type: "admin" })).json.data?.api_token;
ok("viewer can list", (await call("GET", "/admin/driver-applications?status=all", V)).status === 200);
ok("viewer cannot decide", (await call("POST", `/admin/driver-applications/${R.id}/review`, V, { action: "approve" })).status === 403);

ok("approve licence", (await call("PUT", `/admin/driver-applications/${R.id}/documents/${docLic}`, A, { status: "approved" })).status === 200);
rv = await call("POST", `/admin/driver-applications/${R.id}/review`, A, { action: "approve" });
ok("approved", rv.status === 200 && rv.json.status === "approved", JSON.stringify(rv.json));
ok("approving twice is refused", (await call("POST", `/admin/driver-applications/${R.id}/review`, A, { action: "approve" })).status === 409);
const u = (await db.query("select is_verified_driver, service_id from app.users where id = $1", [R.id])).rows[0];
ok("driver flags and ride type set", u.is_verified_driver === true && Number(u.service_id) === svc);
const sw = await call("POST", "/mode", T, { mode: "driver" });
ok("END TO END: approved applicant switches to Driver mode", sw.status === 200 && sw.json.data.active_mode === "driver" && sw.json.data.driver_status === "approved", JSON.stringify(sw.json));

ok("suspend needs a reason", (await call("POST", `/admin/driver-applications/${R.id}/review`, A, { action: "suspend" })).status === 422);
ok("suspend", (await call("POST", `/admin/driver-applications/${R.id}/review`, A, { action: "suspend", note: "Complaints" })).json.status === "suspended");
const after = (await db.query("select active_mode, is_online from app.users where id = $1", [R.id])).rows[0];
ok("suspension forces passenger mode and offline", after.active_mode === "rider" && after.is_online === false);
ok("suspended cannot enter driver mode", (await call("POST", "/mode", T, { mode: "driver" })).json.code === "suspended");
ok("reinstate", (await call("POST", `/admin/driver-applications/${R.id}/review`, A, { action: "reinstate" })).json.status === "approved");
const audits = (await db.query("select action from app.admin_audit where target = $1 order by id", [String(R.id)])).rows.map((r) => r.action);
ok("every decision is in the audit log", ["driver_start_review", "driver_needs_changes", "driver_approve", "driver_suspend", "driver_reinstate"].every((a) => audits.includes(a)), audits.join(","));

await db.query("delete from app.documents where id in ($1,$2,$3,$4)", [docLic, docPap, docOpt, docOther]);
await db.end();
console.log(fails ? `${fails} FAILED` : "ALL PASSED"); process.exit(fails ? 1 : 0);
