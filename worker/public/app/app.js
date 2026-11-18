/* DROP browser sign-in — Phase 1 (shared authentication only).
 *
 * Same account as the unified Flutter app: the session secret travels only in
 * the HttpOnly `drop_session` cookie, which JavaScript can never read. The only
 * token this script ever sees is the CSRF token, which is not a credential:
 * it is useless without the cookie, and the cookie is never exposed here.
 * Nothing is stored in localStorage.
 */
"use strict";
(function () {
  var CSRF_HEADER = "x-csrf-token";

  // CSRF token for authed mutations (POST /web/mode, /web/logout). Kept only
  // in memory: a reload re-fetches it from GET /web/me. Never persisted.
  var csrfToken = null;
  var currentUser = null;
  var accountType = "rider";

  function $(id) { return document.getElementById(id); }

  var viewLoading = $("view-loading");
  var viewAuth = $("view-auth");
  var viewHome = $("view-home");

  function show(view) {
    viewLoading.hidden = view !== "loading";
    viewAuth.hidden = view !== "auth";
    viewHome.hidden = view !== "home";
  }

  function setMsg(el, text, kind) {
    el.textContent = text || "";
    el.className = "msg" + (kind ? " " + kind : "");
  }

  function firstError(body, fallback) {
    if (body && body.errors && typeof body.errors === "object") {
      var keys = Object.keys(body.errors);
      if (keys.length && body.errors[keys[0]] && body.errors[keys[0]][0]) {
        return body.errors[keys[0]][0];
      }
    }
    if (body && typeof body.message === "string" && body.message) return body.message;
    return fallback;
  }

  function readJson(res) {
    return res.json().catch(function () { return {}; });
  }

  // GET /api/web/csrf: readable drop_csrf cookie + JSON body (double submit).
  // POSTs send the JSON value back as X-CSRF-Token; the browser attaches the
  // cookie automatically. Same-origin fetch only — no credentials cross-site.
  function preAuthHeaders(token) {
    var h = { "Content-Type": "application/json" };
    h[CSRF_HEADER] = token;
    return h;
  }

  function authedHeaders() {
    var h = { "Content-Type": "application/json" };
    h[CSRF_HEADER] = csrfToken || "";
    return h;
  }

  function fetchPreAuthCsrf() {
    return fetch("/api/web/csrf", { credentials: "same-origin" })
      .then(function (res) { return readJson(res); })
      .then(function (body) {
        if (!body || !body.csrf_token) throw new Error("csrf");
        return body.csrf_token;
      });
  }

  function checkSession() {
    show("loading");
    var controller = typeof AbortController !== "undefined" ? new AbortController() : null;
    var timeout = controller ? setTimeout(function () { controller.abort(); }, 12000) : null;
    var options = { credentials: "same-origin", cache: "no-store" };
    if (controller) options.signal = controller.signal;
    fetch("/api/web/me", options)
      .then(function (res) { return readJson(res).then(function (b) { return { status: res.status, body: b }; }); })
      .then(function (r) {
        if (r.status === 503) {
          show("auth");
          setMsg($("loginMsg"), "Web sign-in is not configured yet. Please try again later.", "err");
          return;
        }
        if (r.status >= 500) {
          show("auth");
          setMsg($("loginMsg"), "DROP could not verify your session right now. Please try again.", "err");
          return;
        }
        if (r.body && r.body.signed_in && r.body.data) {
          csrfToken = r.body.csrf_token || null;
          renderHome(r.body.data);
        } else {
          show("auth");
        }
      })
      .catch(function (err) {
        show("auth");
        setMsg($("loginMsg"), err && err.name === "AbortError"
          ? "The session check took too long. Check your connection and try again."
          : "Could not reach the server. Check your connection and try again.", "err");
      })
      .finally(function () { if (timeout !== null) clearTimeout(timeout); });
  }

  // ---- tabs + role picker -------------------------------------------------
  function selectTab(which) {
    var login = which === "login";
    $("tab-login").setAttribute("aria-selected", login ? "true" : "false");
    $("tab-register").setAttribute("aria-selected", login ? "false" : "true");
    $("panel-login").hidden = !login;
    $("panel-register").hidden = login;
  }
  $("tab-login").addEventListener("click", function () { selectTab("login"); });
  $("tab-register").addEventListener("click", function () { selectTab("register"); });

  function selectRole(which) {
    accountType = which;
    $("role-rider").setAttribute("aria-checked", which === "rider" ? "true" : "false");
    $("role-driver").setAttribute("aria-checked", which === "driver" ? "true" : "false");
  }
  $("role-rider").addEventListener("click", function () { selectRole("rider"); });
  $("role-driver").addEventListener("click", function () { selectRole("driver"); });

  // Homepage deep links: /app/?register=1 and /app/?register=1&role=driver.
  // The same authentication form is used; the role is only a registration choice.
  try {
    var entry = new URLSearchParams(window.location.search);
    if (entry.get("register") === "1") {
      selectTab("register");
      if (entry.get("role") === "driver") selectRole("driver");
    }
  } catch (_) { /* Keep the normal sign-in default if URL parsing is unavailable. */ }

  // ---- login --------------------------------------------------------------
  $("loginForm").addEventListener("submit", function (ev) {
    ev.preventDefault();
    var msg = $("loginMsg");
    var btn = $("loginBtn");
    var identifier = $("login-identifier").value.trim();
    var password = $("login-password").value;
    if (!identifier) { setMsg(msg, "Enter your phone number or username.", "err"); return; }
    if (!password) { setMsg(msg, "Enter your password.", "err"); return; }
    btn.disabled = true;
    setMsg(msg, "Signing in…");
    fetchPreAuthCsrf()
      .then(function (token) {
        return fetch("/api/web/login", {
          method: "POST",
          credentials: "same-origin",
          headers: preAuthHeaders(token),
          body: JSON.stringify({ identifier: identifier, password: password }),
        });
      })
      .then(function (res) { return readJson(res).then(function (b) { return { status: res.status, body: b }; }); })
      .then(function (r) {
        if (r.status === 403) {
          setMsg(msg, "Request could not be verified. Please reload the page and try again.", "err");
          return;
        }
        if (r.status === 422) {
          setMsg(msg, firstError(r.body, "Check the details and try again."), "err");
          return;
        }
        if (r.body && r.body.status === true && r.body.data) {
          csrfToken = r.body.csrf_token || null;
          renderHome(r.body.data);
          return;
        }
        // 200 with status:false (wrong credentials, banned) — same as the app.
        setMsg(msg, (r.body && r.body.message) || "These credentials do not match our records.", "err");
      })
      .catch(function () {
        setMsg(msg, "Could not reach the server. Check your connection and try again.", "err");
      })
      .finally(function () { btn.disabled = false; });
  });

  // ---- register -----------------------------------------------------------
  $("registerForm").addEventListener("submit", function (ev) {
    ev.preventDefault();
    var msg = $("registerMsg");
    var btn = $("registerBtn");
    var payload = {
      first_name: $("reg-first").value.trim(),
      last_name: $("reg-last").value.trim(),
      email: $("reg-email").value.trim() || null,
      username: $("reg-username").value.trim() || null,
      password: $("reg-password").value,
      user_type: accountType,
      country_code: $("reg-cc").value.trim() || null,
      contact_number: $("reg-phone").value.trim() || null,
      gender: $("reg-gender").value || null,
    };
    if (!payload.first_name || !payload.last_name) {
      setMsg(msg, "Enter your first and last name.", "err");
      return;
    }
    if (!payload.email && !payload.contact_number) {
      setMsg(msg, "Enter your phone number.", "err");
      return;
    }
    if (!payload.password || payload.password.length < 8) {
      setMsg(msg, "The password must be at least 8 characters.", "err");
      return;
    }
    btn.disabled = true;
    setMsg(msg, "Creating your account…");
    fetchPreAuthCsrf()
      .then(function (token) {
        return fetch("/api/web/register", {
          method: "POST",
          credentials: "same-origin",
          headers: preAuthHeaders(token),
          body: JSON.stringify(payload),
        });
      })
      .then(function (res) { return readJson(res).then(function (b) { return { status: res.status, body: b }; }); })
      .then(function (r) {
        if (r.status === 403) {
          setMsg(msg, "Request could not be verified. Please reload the page and try again.", "err");
          return;
        }
        if (r.status === 422) {
          setMsg(msg, firstError(r.body, "Check the details and try again."), "err");
          return;
        }
        if (r.body && r.body.status === true && r.body.data) {
          csrfToken = r.body.csrf_token || null;
          renderHome(r.body.data, r.body.message);
          return;
        }
        setMsg(msg, (r.body && r.body.message) || "Could not create the account. Try again.", "err");
      })
      .catch(function () {
        setMsg(msg, "Could not reach the server. Check your connection and try again.", "err");
      })
      .finally(function () { btn.disabled = false; });
  });

  // ---- signed-in home -----------------------------------------------------
  function isDriver(user) {
    var roles = user && user.roles ? user.roles : [];
    return roles.indexOf("driver") !== -1;
  }

  function renderHome(user, notice) {
    currentUser = user;
    var name = user.display_name || ((user.first_name || "") + " " + (user.last_name || "")).trim() || "there";
    $("hello").textContent = "Welcome, " + name;
    var contact = user.contact_number
      ? (user.country_code || "") + " " + user.contact_number
      : (user.email || user.username || "");
    $("whoLine").textContent = contact ? ("Signed in as " + contact) : "Signed in.";

    var badges = [];
    badges.push({ t: user.user_type === "driver" ? "Driver account" : "Passenger account", on: true });
    badges.push({ t: "Mode: " + (user.active_mode === "driver" ? "Driver" : "Passenger"), on: true });
    if (isDriver(user)) {
      var ds = user.driver_status;
      badges.push({
        t: !ds ? "Driver application: not submitted"
          : ds === "approved" ? "Driver: approved"
          : ds === "submitted" ? "Driver: under review"
          : "Driver: " + ds,
        on: ds === "approved",
      });
    }
    if (user.status && user.status !== "active") {
      badges.push({ t: "Account: " + user.status, on: false });
    }
    $("badges").innerHTML = "";
    badges.forEach(function (b) {
      var s = document.createElement("span");
      s.className = "badge" + (b.on ? " on" : "");
      s.textContent = b.t;
      $("badges").appendChild(s);
    });

    // Driver-mode eligibility mirrors the server's driverModeBlock: only
    // approved drivers in good standing may switch. The server still decides.
    var note = $("driverNote");
    var canDrive = isDriver(user) && user.driver_status === "approved" && user.status === "active";
    if (!isDriver(user)) {
      note.hidden = true;
    } else if (canDrive) {
      note.hidden = true;
    } else {
      note.hidden = false;
      note.textContent = !user.driver_status
        ? "Driver mode unlocks after you apply and DROP approves your application (in the app)."
        : user.driver_status === "submitted"
          ? "Your driver application is still being reviewed. You can use passenger mode meanwhile."
          : user.driver_status === "suspended"
            ? "Your driver account is suspended. Contact support."
            : user.driver_status === "rejected"
              ? "Your driver application was not approved."
              : "Driver mode is not available for this account right now.";
    }

    var riderBtn = $("modeRider");
    var driverBtn = $("modeDriver");
    riderBtn.setAttribute("aria-pressed", user.active_mode === "driver" ? "false" : "true");
    driverBtn.setAttribute("aria-pressed", user.active_mode === "driver" ? "true" : "false");
    driverBtn.disabled = !canDrive && user.active_mode !== "driver";

    var homeMsg = $("homeMsg");
    if (notice) setMsg(homeMsg, notice, "ok");
    else setMsg(homeMsg, "");

    // showWorkspaces() selects the passenger/driver workspace and
    // activateAppScreen() hides the driver application unless it is opened
    // explicitly from Profile.
    showWorkspaces(user);

    show("home");
  }

  function switchMode(mode) {
    var homeMsg = $("homeMsg");
    if (!csrfToken) {
      setMsg(homeMsg, "Your session is not valid. Please log in again.", "err");
      return;
    }
    setMsg(homeMsg, "Switching…");
    fetch("/api/web/mode", {
      method: "POST",
      credentials: "same-origin",
      headers: authedHeaders(),
      body: JSON.stringify({ mode: mode }),
    })
      .then(function (res) { return readJson(res).then(function (b) { return { status: res.status, body: b }; }); })
      .then(function (r) {
        if (r.status === 401) {
          csrfToken = null;
          show("auth");
          setMsg($("loginMsg"), "Your session is not valid. Please log in again.", "err");
          return;
        }
        if (r.status === 422) {
          setMsg(homeMsg, firstError(r.body, "Check and try again."), "err");
          return;
        }
        if (r.body && r.body.status === true && r.body.data) {
          renderHome(r.body.data, mode === "driver" ? "Driver mode on." : "Passenger mode on.");
          return;
        }
        setMsg(homeMsg, (r.body && r.body.message) || "Could not switch mode.", "err");
      })
      .catch(function () {
        setMsg(homeMsg, "Could not reach the server. Check your connection and try again.", "err");
      });
  }

  $("modeRider").addEventListener("click", function () { switchMode("rider"); });
  $("modeDriver").addEventListener("click", function () { switchMode("driver"); });

  $("logoutBtn").addEventListener("click", function () {
    var homeMsg = $("homeMsg");
    var btn = $("logoutBtn");
    btn.disabled = true;
    fetch("/api/web/logout", {
      method: "POST",
      credentials: "same-origin",
      headers: authedHeaders(),
      body: "{}",
    })
      .then(function () {
        csrfToken = null;
        currentUser = null;
        if (driverPollTimer) clearInterval(driverPollTimer);
        if (passengerPollTimer) clearInterval(passengerPollTimer);
        driverPollTimer = null; passengerPollTimer = null;
        daReq = null; daApp = null; daLoadedFor = null;
        routeStops.forEach(function (stop) { if (stop.marker) removeMapMarker(stop.marker); });
        routeStops = []; maxRouteStops = 0;
        $("routeStops").innerHTML = ""; $("addRouteStop").disabled = true; $("routeStopLimit").textContent = "Loading stop limit…";
        $("driverApp").hidden = true;
        $("login-password").value = "";
        show("auth");
        selectTab("login");
        setMsg($("loginMsg"), "Signed out.", "ok");
      })
      .catch(function () {
        setMsg(homeMsg, "Could not reach the server. Try again.", "err");
      })
      .finally(function () { btn.disabled = false; });
  });

  // ---- driver application -------------------------------------------------
  // Same backend as the unified Flutter app (GET/PUT/POST /api/driver/*).
  // Cookie session + X-CSRF-Token, exactly like mode/logout above. Document
  // and photo uploads send the raw file bytes in the request body (never
  // multipart). Document previews link to the auth-protected
  // GET /api/driver/documents/:id/file endpoint, so private files never leak
  // publicly. There is no photo retrieval endpoint in the backend — the API
  // only reports has_photo — so the photo section shows upload status only,
  // never a preview. No public or guessed URLs are used here.
  var daReq = null; // GET /api/driver/requirements
  var daApp = null; // GET /api/driver/application
  var daLoadedFor = null; // user id the forms were loaded for

  var DA_STATUS_LABEL = {
    not_started: "Not started",
    draft: "Draft — in progress",
    needs_changes: "Needs changes",
    submitted: "Submitted — under review",
    approved: "Approved",
    rejected: "Rejected",
    suspended: "Suspended"
  };

  // File + expiry choices the driver picked but has not uploaded yet,
  // keyed by document_id. Survives the document-list re-render that happens
  // when the vehicle type changes; cleared on upload success and fresh load.
  var daPending = {};

  // Submit is only possible while the backend lets this application move.
  function canSubmitNow() {
    return !!daApp && !!daApp.editable &&
      (daApp.status === "draft" || daApp.status === "needs_changes" || daApp.status === "not_started");
  }

  function daReqDocById(id) {
    var docs = (daReq && daReq.documents) || [];
    for (var i = 0; i < docs.length; i++) if (Number(docs[i].id) === Number(id)) return docs[i];
    return null;
  }

  // Service currently picked in the vehicle form. The unsaved choice wins so
  // the document list always matches what the driver sees, not just what is
  // saved on the server.
  function selectedServiceId() {
    var sel = $("da-service");
    if (sel && sel.value) return Number(sel.value);
    return (daApp && daApp.vehicle && daApp.vehicle.service_id) || null;
  }

  // Requirements documents with empty service_ids apply to every ride type;
  // documents naming specific services only apply to the selected type.
  // Unknown ids default to visible — the server is authoritative on submit.
  function docApplies(d) {
    var req = daReqDocById(d.document_id != null ? d.document_id : d.id);
    var ids = (req && req.service_ids) || [];
    if (!ids.length) return true;
    var sel = selectedServiceId();
    if (!sel) return true;
    for (var i = 0; i < ids.length; i++) if (Number(ids[i]) === sel) return true;
    return false;
  }

  // Application documents when the profile exists; otherwise the requirements
  // list shaped like application documents, so a new driver sees upfront
  // what will be needed (requirements docs carry `id`, application docs
  // carry `document_id`).
  function displayDocs() {
    var docs = (daApp && daApp.documents) || [];
    var base = docs.length ? docs : ((daApp && daApp.status === "not_started" && daReq && daReq.documents) || []).map(function (r) {
      return { document_id: r.id, name: r.name, required: r.required, has_expiry_date: r.has_expiry_date, uploaded: false, expire_date: null, status: "missing", requested: false, request_note: null, note: null };
    });
    return base.filter(docApplies);
  }

  // Remember unsaved file/expiry choices before the list is rebuilt.
  function stashPendingDocs() {
    var box = $("daDocs");
    if (!box) return;
    var cards = box.children;
    for (var i = 0; i < cards.length; i++) {
      var getAttr = cards[i].getAttribute && cards[i].getAttribute("data-doc");
      if (!getAttr) continue;
      var fileInput = cards[i].querySelector('input[type="file"]');
      var expInput = cards[i].querySelector('input[type="date"]');
      var entry = daPending[getAttr] || {};
      if (fileInput && fileInput.files && fileInput.files[0]) entry.file = fileInput.files[0];
      if (expInput) entry.expire = expInput.value || null;
      if (entry.file || entry.expire) daPending[getAttr] = entry;
      else delete daPending[getAttr];
    }
  }

  function el(tag, cls, text) {
    var n = document.createElement(tag);
    if (cls) n.className = cls;
    if (text != null) n.textContent = text;
    return n;
  }

  function clear(node) {
    while (node.firstChild) node.removeChild(node.firstChild);
  }

  function sessionExpired() {
    csrfToken = null; currentUser = null;
    daReq = null; daApp = null; daLoadedFor = null;
    $("driverApp").hidden = true;
    show("auth");
    selectTab("login");
    setMsg($("loginMsg"), "Your session is not valid. Please log in again.", "err");
  }

  // Authenticated JSON call. Returns null after handling an expired session
  // so callers can simply stop; 403 CSRF failures are reported, never retried.
  function daFetch(path, opts) {
    opts = opts || {};
    opts.credentials = "same-origin";
    if (!opts.headers) opts.headers = authedHeaders();
    return fetch(path, opts).then(function (res) {
      return readJson(res).then(function (b) { return { status: res.status, body: b }; });
    }).then(function (r) {
      if (r.status === 401) { sessionExpired(); return null; }
      return r;
    });
  }

  function daFailMessage(r, fallback) {
    if (!r) return fallback;
    if (r.status === 403) return "Request could not be verified. Please reload the page and try again.";
    if (r.status === 409) return (r.body && r.body.message) || "This application is locked right now.";
    if (r.status === 413) return "That file is too large.";
    if (r.status === 415) return (r.body && r.body.message) || "That file type is not accepted.";
    if (r.status === 503) return (r.body && r.body.message) || "File uploads are not set up yet. Try again later.";
    if (r.status === 422) return firstError(r.body, fallback);
    return firstError(r.body, fallback);
  }

  function todayStr() {
    var d = new Date();
    return d.getFullYear() + "-" + String(d.getMonth() + 1).padStart(2, "0") + "-" + String(d.getDate()).padStart(2, "0");
  }

  function docById(id) {
    var docs = (daApp && daApp.documents) || [];
    for (var i = 0; i < docs.length; i++) if (Number(docs[i].document_id) === Number(id)) return docs[i];
    return null;
  }

  function missingLabel(m) {
    if (m === "name") return "Your first and last name";
    if (m === "photo") return "Profile photo";
    if (m === "personal") return "Personal information";
    if (m === "vehicle") return "Vehicle details";
    if (m === "date_of_birth") return "Date of birth";
    if (m === "age") return "Minimum age requirement";
    if (m === "vehicle_type") return "Vehicle type";
    if (m === "licence_years") return "Licence experience (years)";
    if (m.indexOf("vehicle_") === 0) return "Vehicle " + m.slice(8).replace(/_/g, " ");
    if (m.indexOf("document_expiry:") === 0) {
      var d1 = docById(m.slice("document_expiry:".length));
      return "Valid expiry date for " + (d1 ? d1.name : "a document");
    }
    if (m.indexOf("document:") === 0) {
      var d2 = docById(m.slice("document:".length));
      return "Upload " + (d2 ? d2.name : "a required document");
    }
    return m;
  }

  // Sections used for the progress bar: personal, photo, vehicle, documents.
  function daSectionState() {
    var p = (daApp && daApp.personal) || {};
    var v = (daApp && daApp.vehicle) || {};
    var personal = !!(p.first_name && p.last_name && p.date_of_birth);
    var photo = !!p.has_photo;
    var vehicle = !!(v.service_id && v.licence_years != null && v.make && v.model && v.year && v.colour && v.plate && v.seats != null);
    // Filtered to the selected vehicle type, matching the visible document
    // list. The server re-checks against the saved service on submit.
    var docs = displayDocs();
    var reqDocs = docs.filter(function (d) { return d.required; });
    var documents = reqDocs.length > 0 && reqDocs.every(function (d) {
      return d.uploaded && d.status !== "rejected" && (!d.has_expiry_date || (d.expire_date && d.expire_date > todayStr()));
    });
    return [
      { key: "personal", done: personal, label: "Personal information" },
      { key: "photo", done: photo, label: "Profile photo" },
      { key: "vehicle", done: vehicle, label: "Vehicle details" },
      { key: "documents", done: documents, label: "Required documents" }
    ];
  }

  function showDriverApp(user) {
    $("driverApp").hidden = false;
    if (daLoadedFor === user.id && daReq && daApp) return;
    daLoadedFor = user.id;
    loadDriverApp();
  }

  function loadDriverApp() {
    daPending = {};
    var statusBox = $("daStatus");
    clear(statusBox);
    statusBox.appendChild(el("span", "badge", "Loading your application…"));
    setMsg($("daSubmitMsg"), "");
    Promise.all([
      daFetch("/api/driver/requirements"),
      daFetch("/api/driver/application")
    ]).then(function (rs) {
      var rq = rs[0], ap = rs[1];
      if (!rq || !ap) return; // session expiry already handled
      if (rq.status !== 200) {
        clear(statusBox);
        setMsg($("daSubmitMsg"), daFailMessage(rq, "Could not load the application. Try again."), "err");
        return;
      }
      if (ap.status !== 200) {
        clear(statusBox);
        setMsg($("daSubmitMsg"), daFailMessage(ap, "Could not load the application. Try again."), "err");
        return;
      }
      daReq = rq.body;
      daApp = ap.body;
      renderDriverApp();
    }).catch(function () {
      clear(statusBox);
      setMsg($("daSubmitMsg"), "Could not reach the server. Check your connection and try again.", "err");
    });
  }

  function renderDriverApp() {
    if (!daApp || !daReq) return;
    var editable = !!daApp.editable;
    var maxMb = daReq.max_upload_mb || 5;

    // Max-size hints.
    var hints = document.getElementsByClassName("da-maxmb");
    for (var hi = 0; hi < hints.length; hi++) hints[hi].textContent = String(maxMb);

    // Overview: status + lock state + requested-doc count.
    var statusBox = $("daStatus");
    clear(statusBox);
    statusBox.appendChild(el("span", "badge on", DA_STATUS_LABEL[daApp.status] || daApp.status));
    statusBox.appendChild(el("span", "badge", editable ? "Editable" : "Locked"));
    if (daApp.documents_requested) {
      statusBox.appendChild(el("span", "badge", daApp.documents_requested + " document" + (daApp.documents_requested === 1 ? "" : "s") + " requested by admin"));
    }

    // Admin review note.
    var note = $("daReviewNote");
    if (daApp.review_note) {
      note.hidden = false;
      note.textContent = "From DROP review: " + daApp.review_note;
    } else {
      note.hidden = true;
      note.textContent = "";
    }

    // Progress.
    var sections = daSectionState();
    var done = sections.filter(function (s) { return s.done; }).length;
    var pct = Math.round((done / sections.length) * 100);
    $("daBar").style.width = pct + "%";
    $("daProgressBar").setAttribute("aria-valuenow", String(pct));
    $("daProgressText").textContent = done === sections.length
      ? "Everything looks complete — review and submit below."
      : "Next: " + sections.filter(function (s) { return !s.done; }).map(function (s) { return s.label; }).join(", ") + ".";

    // Outstanding list (client view; the server's missing[] list appears here after a submit attempt).
    renderOutstanding(null);

    // Personal form.
    $("da-first").value = daApp.personal.first_name || "";
    $("da-last").value = daApp.personal.last_name || "";
    $("da-dob").value = daApp.personal.date_of_birth || "";
    $("da-first").disabled = !editable;
    $("da-last").disabled = !editable;
    $("da-dob").disabled = !editable;
    $("daPersonalBtn").disabled = !editable;
    setMsg($("daPersonalMsg"), "");

    // Photo.
    $("daPhotoState").textContent = daApp.personal.has_photo ? "Photo on file ✓" : "No photo yet.";
    $("daPhoto").disabled = !editable;
    $("daPhotoBtn").disabled = !editable;
    setMsg($("daPhotoMsg"), "");

    // Vehicle select options come from the server (region-filtered ride types).
    var svcSel = $("da-service");
    clear(svcSel);
    var placeholder = el("option", null, "Choose vehicle type");
    placeholder.value = "";
    svcSel.appendChild(placeholder);
    (daReq.vehicles || []).forEach(function (s) {
      var o = document.createElement("option");
      o.value = String(s.id);
      o.textContent = s.name + (s.capacity ? " · up to " + s.capacity + " seats" : "");
      if (daApp.vehicle && String(daApp.vehicle.service_id) === String(s.id)) o.selected = true;
      svcSel.appendChild(o);
    });
    var vv = daApp.vehicle || {};
    $("da-licence").value = vv.licence_years != null ? String(vv.licence_years) : "";
    $("da-make").value = vv.make || "";
    $("da-model").value = vv.model || "";
    $("da-year").value = vv.year || "";
    $("da-colour").value = vv.colour || "";
    $("da-plate").value = vv.plate || "";
    $("da-seats").value = vv.seats != null ? String(vv.seats) : "";
    applySeatCap();
    ["da-service", "da-licence", "da-make", "da-model", "da-year", "da-colour", "da-plate", "da-seats"].forEach(function (id) {
      $(id).disabled = !editable;
    });
    $("daVehicleBtn").disabled = !editable;
    setMsg($("daVehicleMsg"), "");

    // Documents.
    renderDocs(editable);

    // Submit.
    $("daSubmitBtn").disabled = !canSubmitNow();
    if (daApp.status === "rejected" && editable) {
      $("daSubmitHint").textContent = "Saving any change above reopens your application as a draft, then you can submit.";
    } else if (!editable) {
      $("daSubmitHint").textContent = "This application is locked while it is under review or approved.";
    } else {
      $("daSubmitHint").textContent = "When every section above is complete, submit your application.";
    }
  }

  function renderOutstanding(serverMissing) {
    var list = $("daMissing");
    clear(list);
    var items = [];
    if (serverMissing && serverMissing.length) {
      serverMissing.forEach(function (m) { items.push(missingLabel(m)); });
    } else {
      var sections = daSectionState();
      sections.forEach(function (s) { if (!s.done) items.push(s.label + " incomplete"); });
      // Only documents visible for the selected vehicle type. Requested and
    // rejected flags always come from the server, so nothing required can be
    // reported as fine, and nothing inapplicable is listed as outstanding.
    displayDocs().forEach(function (d) {
        if (d.requested) items.push(d.request_note ? d.name + ": " + d.request_note : d.name + " requested by admin");
        else if (d.uploaded && d.status === "rejected") items.push(d.name + " was rejected" + (d.note ? ": " + d.note : " — upload a new one"));
      });
    }
    items.forEach(function (t) { list.appendChild(el("li", null, t)); });
  }

  function applySeatCap() {
    var sel = $("da-service");
    var seats = $("da-seats");
    var chosen = (daReq.vehicles || []).filter(function (s) { return String(s.id) === sel.value; })[0];
    if (chosen && chosen.capacity) {
      seats.max = String(chosen.capacity);
      seats.title = "This vehicle type seats at most " + chosen.capacity + ".";
    } else {
      seats.max = "60";
      seats.title = "";
    }
  }

  // Changing the vehicle type re-filters the document list (documents bound
  // to other ride types hide); pending choices and saved vehicle fields stay.
  $("da-service").addEventListener("change", function () {
    applySeatCap();
    stashPendingDocs();
    renderDocs(!!(daApp && daApp.editable));
    renderOutstanding(null);
  });

  function renderDocs(editable) {
    var box = $("daDocs");
    clear(box);
    var docs = displayDocs();
    if (!docs.length) {
      box.appendChild(el("p", "muted small", "No documents are required for this vehicle type right now."));
      return;
    }
    docs.forEach(function (d) {
      var card = el("div", "doc" + (d.requested ? " requested" : ""));
      card.setAttribute("data-doc", String(d.document_id));
      var head = el("div", "doc-head");
      head.appendChild(el("strong", null, d.name + (d.required ? " *" : "")));
      var st = d.status === "approved" ? "Approved" : d.status === "rejected" ? "Rejected" : d.status === "pending" ? "Under review" : "Missing";
      head.appendChild(el("span", "badge" + (d.status === "approved" ? " on" : ""), st));
      card.appendChild(head);
      if (d.expire_date) card.appendChild(el("p", "muted small", "Expires: " + d.expire_date));
      if (d.requested) card.appendChild(el("p", "doc-note", d.request_note ? "Admin asked for this: " + d.request_note : "Admin asked for this document."));
      else if (d.note) card.appendChild(el("p", "doc-note", "Review note: " + d.note));
      if (d.uploaded) {
        var view = el("p", null, null);
        var a = document.createElement("a");
        a.className = "doc-view";
        a.href = "/api/driver/documents/" + d.document_id + "/file";
        a.target = "_blank";
        a.rel = "noopener";
        a.textContent = "View uploaded file";
        view.appendChild(a);
        card.appendChild(view);
      }
      var row = el("div", "doc-row");
      var file = document.createElement("input");
      file.type = "file";
      file.accept = ".jpg,.jpeg,.png,.webp,.pdf,image/jpeg,image/png,image/webp,application/pdf";
      file.setAttribute("aria-label", "File for " + d.name);
      var exp = null;
      if (d.has_expiry_date) {
        exp = document.createElement("input");
        exp.type = "date";
        exp.min = todayStr();
        exp.value = d.expire_date || "";
        exp.setAttribute("aria-label", "Expiry date for " + d.name);
        row.appendChild(exp);
      }
      row.appendChild(file);
      var btn = document.createElement("button");
      btn.type = "button";
      btn.className = "small-btn";
      btn.textContent = d.uploaded ? "Replace" : "Upload";
      var mayUpload = editable || d.requested;
      var pend = daPending[String(d.document_id)];
      if (pend) {
        if (exp && pend.expire && !exp.value) exp.value = pend.expire;
        // A File object cannot be restored into an <input>; surface the
        // stashed choice so the driver knows it still needs uploading.
        if (pend.file && !(file.files && file.files[0])) {
          card.appendChild(el("p", "muted small", "Selected earlier: " + pend.file.name + " — choose it again and press " + btn.textContent + "."));
        }
      }
      file.disabled = !mayUpload;
      if (exp) exp.disabled = !mayUpload;
      btn.disabled = !mayUpload;
      btn.addEventListener("click", function () { uploadDoc(d, file, exp, btn); });
      row.appendChild(btn);
      card.appendChild(row);
      box.appendChild(card);
    });
  }

  function checkFile(file, isPhoto, maxMb) {
    if (!file) return "Choose a file first.";
    if (file.size === 0) return "That file is empty.";
    if (file.size > maxMb * 1024 * 1024) return "That file is too large (" + maxMb + " MB maximum).";
    var t = (file.type || "").toLowerCase();
    var okImage = t === "image/jpeg" || t === "image/png" || t === "image/webp";
    var okDoc = okImage || t === "application/pdf";
    if (isPhoto ? !okImage : !okDoc) {
      return isPhoto ? "The photo must be a JPG, PNG or WebP image." : "Upload a JPG, PNG, WebP or PDF file.";
    }
    return null;
  }

  function uploadDoc(d, fileInput, expInput, btn) {
    var msg = $("daDocsMsg");
    var files = fileInput.files;
    var file = files && files[0];
    var bad = checkFile(file, false, daReq.max_upload_mb || 5);
    if (bad) { setMsg(msg, bad, "err"); return; }
    if (d.has_expiry_date && (!expInput.value || expInput.value <= todayStr())) {
      setMsg(msg, "Enter the expiry date (it must be in the future).", "err");
      return;
    }
    btn.disabled = true;
    setMsg(msg, "Uploading " + d.name + "…");
    var path = "/api/driver/documents/" + d.document_id + (d.has_expiry_date ? "?expire_date=" + encodeURIComponent(expInput.value) : "");
    var h = authedHeaders();
    h["Content-Type"] = file.type || "application/octet-stream";
    daFetch(path, { method: "PUT", headers: h, body: file })
      .then(function (r) {
        if (!r) return;
        if (r.status !== 200) { setMsg(msg, daFailMessage(r, "Could not upload. Try again."), "err"); return; }
        setMsg(msg, d.name + " uploaded.", "ok");
        fileInput.value = "";
        delete daPending[String(d.document_id)];
        refreshAfterSave();
      }).catch(function () {
        setMsg(msg, "Could not reach the server. Check your connection and try again.", "err");
      }).finally(function () { btn.disabled = false; });
  }

  // Personal information: PUT /api/driver/application/personal
  $("daPersonalForm").addEventListener("submit", function (ev) {
    ev.preventDefault();
    var msg = $("daPersonalMsg");
    var btn = $("daPersonalBtn");
    var payload = {
      first_name: $("da-first").value.trim(),
      last_name: $("da-last").value.trim(),
      date_of_birth: $("da-dob").value
    };
    if (!payload.first_name || !payload.last_name) { setMsg(msg, "Enter your first and last name.", "err"); return; }
    if (!/^\d{4}-\d{2}-\d{2}$/.test(payload.date_of_birth)) { setMsg(msg, "Enter your date of birth.", "err"); return; }
    btn.disabled = true;
    setMsg(msg, "Saving…");
    var h = authedHeaders();
    h["Content-Type"] = "application/json";
    daFetch("/api/driver/application/personal", { method: "PUT", headers: h, body: JSON.stringify(payload) })
      .then(function (r) {
        if (!r) return;
        if (r.status !== 200) { setMsg(msg, daFailMessage(r, "Could not save. Try again."), "err"); return; }
        setMsg(msg, "Personal information saved.", "ok");
        refreshAfterSave();
      }).catch(function () {
        setMsg(msg, "Could not reach the server. Check your connection and try again.", "err");
      }).finally(function () { btn.disabled = !daApp || !daApp.editable; });
  });

  // Profile photo: PUT /api/driver/application/photo (raw image bytes)
  $("daPhotoBtn").addEventListener("click", function () {
    var msg = $("daPhotoMsg");
    var btn = $("daPhotoBtn");
    var files = $("daPhoto").files;
    var file = files && files[0];
    var bad = checkFile(file, true, daReq ? (daReq.max_upload_mb || 5) : 5);
    if (bad) { setMsg(msg, bad, "err"); return; }
    btn.disabled = true;
    setMsg(msg, "Uploading photo…");
    var h = authedHeaders();
    h["Content-Type"] = file.type || "application/octet-stream";
    daFetch("/api/driver/application/photo", { method: "PUT", headers: h, body: file })
      .then(function (r) {
        if (!r) return;
        if (r.status !== 200) { setMsg(msg, daFailMessage(r, "Could not upload. Try again."), "err"); return; }
        setMsg(msg, "Photo uploaded.", "ok");
        $("daPhoto").value = "";
        refreshAfterSave();
      }).catch(function () {
        setMsg(msg, "Could not reach the server. Check your connection and try again.", "err");
      }).finally(function () { btn.disabled = !daApp || !daApp.editable; });
  });

  // Vehicle: PUT /api/driver/application/vehicle
  $("daVehicleForm").addEventListener("submit", function (ev) {
    ev.preventDefault();
    var msg = $("daVehicleMsg");
    var btn = $("daVehicleBtn");
    var payload = {
      service_id: Number($("da-service").value),
      licence_years: Number($("da-licence").value),
      make: $("da-make").value.trim(),
      model: $("da-model").value.trim(),
      year: $("da-year").value.trim(),
      colour: $("da-colour").value.trim(),
      plate: $("da-plate").value.trim(),
      seats: Number($("da-seats").value)
    };
    if (!payload.service_id) { setMsg(msg, "Choose your vehicle type.", "err"); return; }
    if (!/^(19|20)\d{2}$/.test(payload.year)) { setMsg(msg, "Enter a valid vehicle year (e.g. 2019).", "err"); return; }
    if (!payload.make || !payload.model || !payload.colour || !payload.plate) {
      setMsg(msg, "Fill in the make, model, colour and plate number.", "err");
      return;
    }
    btn.disabled = true;
    setMsg(msg, "Saving…");
    var h = authedHeaders();
    h["Content-Type"] = "application/json";
    daFetch("/api/driver/application/vehicle", { method: "PUT", headers: h, body: JSON.stringify(payload) })
      .then(function (r) {
        if (!r) return;
        if (r.status !== 200) { setMsg(msg, daFailMessage(r, "Could not save. Try again."), "err"); return; }
        setMsg(msg, "Vehicle saved.", "ok");
        refreshAfterSave();
      }).catch(function () {
        setMsg(msg, "Could not reach the server. Check your connection and try again.", "err");
      }).finally(function () { btn.disabled = !daApp || !daApp.editable; });
  });

  // Submit: POST /api/driver/application/submit
  $("daSubmitBtn").addEventListener("click", function () {
    var msg = $("daSubmitMsg");
    var btn = $("daSubmitBtn");
    btn.disabled = true;
    setMsg(msg, "Submitting…");
    var h = authedHeaders();
    h["Content-Type"] = "application/json";
    daFetch("/api/driver/application/submit", { method: "POST", headers: h, body: "{}" })
      .then(function (r) {
        if (!r) return;
        if (r.status !== 200) {
          if (r.body && r.body.missing && r.body.missing.length) renderOutstanding(r.body.missing);
          setMsg(msg, daFailMessage(r, "Your application is not complete yet."), "err");
          return;
        }
        setMsg(msg, "Submitted — DROP will review your application.", "ok");
        refreshAfterSave();
        return;
      }).catch(function () {
        setMsg(msg, "Could not reach the server. Check your connection and try again.", "err");
      }).finally(function () { syncSubmitBtn(btn); });
  });

  // The submit button stays disabled while locked or after a successful
  // submit; it becomes usable again after failures. renderDriverApp owns the
  // steady state, so only restore from a stale snapshot when no reload is in
  // flight — otherwise refreshAfterSave's render decides.
  var daReloading = false;
  function syncSubmitBtn(btn) {
    if (daReloading) return;
    btn.disabled = !canSubmitNow();
  }

  // After a save/submit: reload the application (a rejected one reopens as
  // a draft server-side) and refresh the header badges from /web/me.
  function refreshAfterSave() {
    daReloading = true;
    daFetch("/api/driver/requirements").then(function (rq) {
      if (!rq || rq.status !== 200) return null;
      daReq = rq.body;
      return daFetch("/api/driver/application");
    }).then(function (ap) {
      if (!ap || ap.status !== 200) return;
      daApp = ap.body;
      renderDriverApp();
    }).catch(function () {
      setMsg($("daSubmitMsg"), "Saved, but the view could not refresh. Reload the page.", "err");
    }).finally(function () {
      daReloading = false;
      var sb = $("daSubmitBtn");
      if (sb) sb.disabled = !canSubmitNow();
    });
    fetch("/api/web/me", { credentials: "same-origin" })
      .then(function (res) { return readJson(res).then(function (b) { return { status: res.status, body: b }; }); })
      .then(function (r) {
        if (r.body && r.body.signed_in && r.body.data) {
          csrfToken = r.body.csrf_token || csrfToken;
          currentUser = r.body.data;
          renderBadges(currentUser);
        }
      }).catch(function () { /* badges stay as they are; the reload above is authoritative */ });
  }

  // Header badges shared with the sign-in flow, so approval shows up at once.
  function renderBadges(user) {
    var badges = [];
    badges.push({ t: user.user_type === "driver" ? "Driver account" : "Passenger account", on: true });
    badges.push({ t: "Mode: " + (user.active_mode === "driver" ? "Driver" : "Passenger"), on: true });
    if (isDriver(user)) {
      var ds = user.driver_status;
      badges.push({
        t: !ds ? "Driver application: not submitted"
          : ds === "approved" ? "Driver: approved"
          : ds === "submitted" ? "Driver: under review"
          : "Driver: " + ds,
        on: ds === "approved",
      });
    }
    if (user.status && user.status !== "active") {
      badges.push({ t: "Account: " + user.status, on: false });
    }
    var box = $("badges");
    clear(box);
    badges.forEach(function (b) {
      var s = document.createElement("span");
      s.className = "badge" + (b.on ? " on" : "");
      s.textContent = b.t;
      box.appendChild(s);
    });
  }


  // ---- passenger and driver web workspaces -------------------------------
  var rideMap = null, pickupPoint = null, dropoffPoint = null;
  var pickupMarker = null, dropoffMarker = null, driverMarker = null, selectedRideType = null, lastQuote = null;
  var routeStops = [], maxRouteStops = 0;
  var driverOnline = false, driverPollTimer = null, passengerPollTimer = null;
  function api(path, options) {
    options = options || {};
    options.credentials = "same-origin";
    options.headers = Object.assign({}, options.headers || {}, authedHeaders());
    return fetch("/api" + path, options).then(function (res) {
      return readJson(res).then(function (body) { if (res.status === 401) { csrfToken = null; if (viewAuth && viewHome) { show("auth"); setMsg($("loginMsg"), "Your session has expired. Please sign in again.", "err"); } } return { status: res.status, body: body }; });
    });
  }
  function money(value, currency) {
    var code = currency && (currency.code || currency.currency) || "NGN";
    try { return new Intl.NumberFormat("en-NG", { style: "currency", currency: code, maximumFractionDigits: 0 }).format(Number(value || 0)); }
    catch (_) { return code + " " + Number(value || 0).toLocaleString(); }
  }
  function setPassengerMessage(message, kind) { setMsg($("passengerMsg"), message, kind); }
  function pointLabel(p) { return p ? p.lat.toFixed(5) + ", " + p.lng.toFixed(5) : "Not selected"; }
  function clearAddressPoint(which) {
    if (which === "pickup") { pickupPoint = null; if (pickupMarker) removeMapMarker(pickupMarker); pickupMarker = null; }
    else if (which === "dropoff") { dropoffPoint = null; if (dropoffMarker) removeMapMarker(dropoffMarker); dropoffMarker = null; }
    else if (String(which).indexOf("stop:") === 0) {
      var stop = routeStops[Number(String(which).split(":")[1])];
      if (stop) { stop.point = null; if (stop.marker) removeMapMarker(stop.marker); stop.marker = null; }
    }
    updateSelectedCoords(); invalidateRideQuote();
  }
  function attachAddressAutocomplete(input, target, onChoose) {
    if (!input || input.dataset.autocompleteReady === "1") return;
    input.dataset.autocompleteReady = "1";
    var wrapper = document.createElement("div"); wrapper.className = "address-autocomplete";
    input.parentNode.insertBefore(wrapper, input); wrapper.appendChild(input);
    var list = document.createElement("div"); list.className = "address-suggestions"; list.hidden = true;
    list.setAttribute("role", "listbox"); wrapper.appendChild(list);
    var timer = null, requestNo = 0, lastSelected = "";
    function close() { list.hidden = true; list.innerHTML = ""; }
    function choose(hit) {
      var label = [hit.title, hit.subtitle].filter(Boolean).join(", ");
      input.value = label; lastSelected = label; input.dataset.selectedAddress = label;
      close();
      if (onChoose) onChoose(label);
      var key = typeof target === "function" ? target() : target;
      setPoint(key, { lat: Number(hit.lat), lng: Number(hit.lng) });
      if (rideMap) setMapView({ lat: Number(hit.lat), lng: Number(hit.lng) }, 16);
    }
    input.addEventListener("input", function () {
      var q = input.value.trim(), key = typeof target === "function" ? target() : target;
      if (q !== lastSelected) { lastSelected = ""; input.dataset.selectedAddress = ""; clearAddressPoint(key); if (onChoose) onChoose(""); }
      if (timer) clearTimeout(timer);
      close();
      var serial = ++requestNo;
      if (q.length < 3) return;
      timer = setTimeout(function () {
        var near = pickupPoint;
        var params = new URLSearchParams({ q: q });
        if (near) { params.set("lat", String(near.lat)); params.set("lng", String(near.lng)); }
        api("/places/search?" + params.toString()).then(function (r) {
          if (serial !== requestNo || input.value.trim() !== q) return;
          var hits = r.body && r.body.data || [];
          list.innerHTML = "";
          if (!Array.isArray(hits) || !hits.length) {
            var empty = document.createElement("div"); empty.className = "address-suggestion-empty"; empty.textContent = "No matching places. Try a nearby landmark or a more specific address."; list.appendChild(empty); list.hidden = false; return;
          }
          hits.slice(0, 8).forEach(function (hit) {
            var option = document.createElement("button"); option.type = "button"; option.className = "address-suggestion"; option.setAttribute("role", "option");
            var title = document.createElement("strong"); title.textContent = hit.title || hit.subtitle || "Place";
            var subtitle = document.createElement("small"); subtitle.textContent = hit.subtitle || "";
            option.append(title, subtitle);
            option.addEventListener("mousedown", function (event) { event.preventDefault(); choose(hit); });
            list.appendChild(option);
          });
          list.hidden = false;
        }).catch(function () {
          if (serial !== requestNo) return;
          list.innerHTML = ""; var err = document.createElement("div"); err.className = "address-suggestion-empty"; err.textContent = "Address search is temporarily unavailable. You can still choose the location on the map."; list.appendChild(err); list.hidden = false;
        });
      }, 280);
    });
    input.addEventListener("keydown", function (event) {
      if (event.key === "Escape") close();
      if (event.key === "ArrowDown" && !list.hidden) { var first = list.querySelector("button"); if (first) { event.preventDefault(); first.focus(); } }
    });
    input.addEventListener("blur", function () { setTimeout(close, 160); });
  }
  function invalidateRideQuote() {
    lastQuote = null; selectedRideType = null;
    $("fareOptions").innerHTML = "";
    $("requestRideWrap").hidden = true;
  }
  function renderRouteStops() {
    var box = $("routeStops");
    if (!box) return;
    box.innerHTML = "";
    routeStops.forEach(function (stop, index) {
      var row = document.createElement("div"); row.className = "route-stop-row";
      var fieldWrap = document.createElement("div");
      var label = document.createElement("label"); label.className = "f"; label.textContent = "Stop " + (index + 1);
      var input = document.createElement("input"); input.type = "text"; input.maxLength = 300;
      input.placeholder = "Enter a landmark or address"; input.value = stop.address || "";
      input.setAttribute("aria-label", "Stop " + (index + 1) + " address");
      input.addEventListener("input", function () { stop.address = input.value; invalidateRideQuote(); });
      attachAddressAutocomplete(input, function () { return "stop:" + index; }, function (label) { stop.address = label; });
      fieldWrap.append(label, input);
      var mapLabel = document.createElement("label"); mapLabel.className = "route-stop-map";
      var radio = document.createElement("input"); radio.type = "radio"; radio.name = "mapTarget"; radio.value = "stop:" + index;
      mapLabel.append(radio, document.createTextNode("Set on map"));
      var remove = document.createElement("button"); remove.type = "button"; remove.className = "route-stop-remove";
      remove.textContent = "Remove"; remove.setAttribute("aria-label", "Remove stop " + (index + 1));
      remove.addEventListener("click", function () {
        if (stop.marker) removeMapMarker(stop.marker);
        routeStops.splice(index, 1);
        renderRouteStops(); updateSelectedCoords(); invalidateRideQuote();
      });
      row.append(fieldWrap, mapLabel, remove);
      if (stop.point) {
        var selected = document.createElement("p"); selected.className = "muted small";
        selected.textContent = "Map point: " + pointLabel(stop.point);
        fieldWrap.appendChild(selected);
      }
      box.appendChild(row);
    });
    $("addRouteStop").disabled = maxRouteStops < 1 || routeStops.length >= maxRouteStops;
    $("routeStopLimit").textContent = maxRouteStops > 0
      ? routeStops.length + " of " + maxRouteStops + " additional stops"
      : "Additional stops are disabled by DROP Admin";
  }
  function updateSelectedCoords() {
    var stopText = routeStops.map(function (s, i) { return "Stop " + (i + 1) + ": " + pointLabel(s.point); }).join(" · ");
    $("selectedCoords").textContent = "Pickup: " + pointLabel(pickupPoint) +
      (stopText ? " · " + stopText : "") + " · Destination: " + pointLabel(dropoffPoint);
  }
  function loadRouteStopSettings() {
    api("/ride/stop-settings").then(function (r) {
      if (r.status === 200 && r.body && r.body.data) {
        maxRouteStops = Math.max(0, Math.min(20, Number(r.body.data.max_additional_stops) || 0));
        if (routeStops.length > maxRouteStops) {
          routeStops.slice(maxRouteStops).forEach(function (stop) { if (stop.marker) removeMapMarker(stop.marker); });
          routeStops = routeStops.slice(0, maxRouteStops);
        }
        renderRouteStops(); updateSelectedCoords();
      } else {
        $("routeStopLimit").textContent = "Could not load stop limit";
        $("addRouteStop").disabled = true;
      }
    }).catch(function () { $("routeStopLimit").textContent = "Could not load stop limit"; $("addRouteStop").disabled = true; });
  }
  function routeStopPayload() {
    var stops = [];
    for (var i = 0; i < routeStops.length; i++) {
      var stop = routeStops[i];
      if (!stop.point) {
        setPassengerMessage("Set Stop " + (i + 1) + " on the map before calculating the fare.", "err");
        return null;
      }
      stops.push({ lat: stop.point.lat, lng: stop.point.lng, address: stop.address.trim() });
    }
    return stops;
  }
  var mapProvider = null, mapConfig = null, passengerMarker = null, passengerWatchId = null;
  function markerElement(kind, iconUrl) {
    var el = document.createElement("div");
    el.className = "drop-map-marker drop-map-marker-" + kind;
    if (iconUrl) { var img = document.createElement("img"); img.src = iconUrl; img.alt = ""; el.appendChild(img); }
    else { var dot = document.createElement("span"); dot.className = "drop-map-dot"; el.appendChild(dot); }
    return el;
  }
  function createMapMarker(point, kind, iconUrl, rotation) {
    if (!rideMap || !point) return null;
    var el = markerElement(kind, iconUrl);
    if (rotation != null) el.style.setProperty("--marker-heading", rotation + "deg");
    if (mapProvider === "mapbox" && window.mapboxgl) return new mapboxgl.Marker({ element: el, anchor: "center", rotationAlignment: "map" }).setLngLat([point.lng, point.lat]).addTo(rideMap);
    if (window.L) return L.marker([point.lat, point.lng], { icon: L.divIcon({ className: "drop-leaflet-marker", html: el.outerHTML, iconSize: [42, 42], iconAnchor: [21, 21] }) }).addTo(rideMap);
    return null;
  }
  function moveMapMarker(marker, point, rotation) {
    if (!marker || !point) return;
    if (typeof marker.setLngLat === "function") marker.setLngLat([point.lng, point.lat]);
    else if (typeof marker.setLatLng === "function") marker.setLatLng([point.lat, point.lng]);
    if (rotation != null && marker.getElement) marker.getElement().style.setProperty("--marker-heading", rotation + "deg");
  }
  function removeMapMarker(marker) {
    if (!marker) return;
    if (typeof marker.remove === "function") marker.remove();
    else if (rideMap && typeof rideMap.removeLayer === "function") rideMap.removeLayer(marker);
  }
  function setPoint(which, latlng) {
    var p = { lat: Number(latlng.lat), lng: Number(latlng.lng) };
    if (!Number.isFinite(p.lat) || !Number.isFinite(p.lng)) return;
    if (which === "pickup") {
      pickupPoint = p;
      if (pickupMarker) moveMapMarker(pickupMarker, p); else pickupMarker = createMapMarker(p, "pickup");
    } else if (which === "dropoff") {
      dropoffPoint = p;
      if (dropoffMarker) moveMapMarker(dropoffMarker, p); else dropoffMarker = createMapMarker(p, "dropoff");
    } else if (String(which).indexOf("stop:") === 0) {
      var index = Number(String(which).split(":")[1]), stop = routeStops[index];
      if (!stop) return;
      stop.point = p;
      if (stop.marker) moveMapMarker(stop.marker, p); else stop.marker = createMapMarker(p, "stop");
      renderRouteStops();
    }
    updateSelectedCoords();
    invalidateRideQuote();
  }
  function setMapView(point, zoom) {
    if (!rideMap) return;
    if (mapProvider === "mapbox" && rideMap.flyTo) rideMap.flyTo({ center: [point.lng, point.lat], zoom: zoom || 15, essential: true });
    else if (rideMap.setView) rideMap.setView([point.lat, point.lng], zoom || 15);
  }
  function watchPassengerLocation() {
    if (!navigator.geolocation || passengerWatchId !== null) return;
    passengerWatchId = navigator.geolocation.watchPosition(function (pos) {
      var p = { lat: pos.coords.latitude, lng: pos.coords.longitude }, heading = Number.isFinite(pos.coords.heading) ? pos.coords.heading : null;
      if (!passengerMarker) passengerMarker = createMapMarker(p, "passenger", null, heading);
      else moveMapMarker(passengerMarker, p, heading);
    }, function () {}, { enableHighAccuracy: true, maximumAge: 5000, timeout: 15000 });
  }
  function initRideMap() {
    if (rideMap || !$("rideMap")) return;
    fetch("/api/map-config", { credentials: "same-origin" }).then(readJson).then(function (cfg) {
      mapConfig = cfg || {}; mapProvider = mapConfig.provider || "osm";
      if (mapProvider === "mapbox") {
        if (!window.mapboxgl || !mapConfig.mapbox_public_token || !mapConfig.mapbox_style_uri) throw new Error("Mapbox is active in DROP Admin, but its web map assets or public configuration are unavailable.");
        mapboxgl.accessToken = mapConfig.mapbox_public_token;
        rideMap = new mapboxgl.Map({ container: "rideMap", style: mapConfig.mapbox_style_uri, center: [-7.4951, 9.0579], zoom: 12, attributionControl: true });
        rideMap.addControl(new mapboxgl.NavigationControl(), "top-right");
        rideMap.on("click", function (e) { var target = document.querySelector('input[name="mapTarget"]:checked'); setPoint(target ? target.value : "pickup", { lat: e.lngLat.lat, lng: e.lngLat.lng }); });
      } else if (mapProvider === "osm" || mapProvider === "auto") {
        if (!window.L) throw new Error("The OpenStreetMap web map library could not be loaded.");
        rideMap = L.map("rideMap").setView([9.0579, 7.4951], 12);
        L.tileLayer(mapConfig.osm_tile_url || "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", { maxZoom: 19, attribution: mapConfig.attribution || "© OpenStreetMap contributors" }).addTo(rideMap);
        rideMap.on("click", function (e) { var target = document.querySelector('input[name="mapTarget"]:checked'); setPoint(target ? target.value : "pickup", e.latlng); });
      } else throw new Error("The backend-selected map provider (" + mapProvider + ") is not configured for browser rendering. Configure its public web key before using it on web.");
      watchPassengerLocation();
      setTimeout(function () { if (rideMap && rideMap.resize) rideMap.resize(); else if (rideMap && rideMap.invalidateSize) rideMap.invalidateSize(); }, 150);
    }).catch(function (err) { setPassengerMessage(err.message || "Could not load the map configuration.", "err"); });
  }
  attachAddressAutocomplete($("pickupAddress"), "pickup");
  attachAddressAutocomplete($("dropoffAddress"), "dropoff");
  var activeAppScreen = "home";
  function activateAppScreen(screen) {
    var allowed = ["home", "trips", "wallet", "profile", "help", "driver-application"];
    if (allowed.indexOf(screen) < 0) screen = "home";
    activeAppScreen = screen;
    var driverMode = currentUser && currentUser.active_mode === "driver";
    var dashboard = driverMode ? $("driverDashboard") : $("passengerDashboard");
    if (!dashboard) return;
    dashboard.querySelectorAll("[data-screen-panel]").forEach(function (panel) {
      panel.hidden = panel.getAttribute("data-screen-panel") !== screen;
    });
    $("appNavigation").hidden = false;
    if ($("backToProfile")) $("backToProfile").addEventListener("click", function () { activateAppScreen("profile"); });
  $("appNavigation").querySelectorAll("[data-screen]").forEach(function (button) {
      var selected = button.getAttribute("data-screen") === screen;
      button.classList.toggle("active", selected);
      button.setAttribute("aria-current", selected ? "page" : "false");
    });
    $("appModeLabel").textContent = driverMode ? "Driver app" : "Passenger app";
    if (screen === "wallet") {
      if (driverMode) {
        var wallet = $("driverWalletContent");
        if (wallet.dataset.loaded !== "1") {
          api("/driver/status").then(function (r) {
            var w = r.body && r.body.wallet || {};
            wallet.innerHTML = "";
            var p = document.createElement("p"); p.className = "wallet-balance"; p.textContent = money(w.balance, {code:"NGN"});
            var label = document.createElement("p"); label.className = "muted"; label.textContent = "Available driver wallet balance";
            wallet.append(p, label); wallet.dataset.loaded = "1";
          }).catch(function () { wallet.textContent = "Could not load your driver wallet. Try again."; });
        }
      } else {
        var pw = $("passengerWalletContent");
        if (pw.dataset.loaded !== "1") {
          api("/wallet-list?per_page=10").then(function (r) {
            var rows = r.body && r.body.data || [];
            pw.innerHTML = "";
            if (!Array.isArray(rows) || !rows.length) { pw.textContent = "No wallet transactions yet."; pw.dataset.loaded = "1"; return; }
            rows.slice(0,10).forEach(function (entry) {
              var item = document.createElement("article"); item.className = "history-item";
              var title = document.createElement("strong"); title.textContent = entry.description || String(entry.transaction_type || "Wallet transaction").replace(/_/g," ");
              var amount = document.createElement("p"); amount.textContent = money(entry.amount, {code:"NGN"});
              item.append(title, amount); pw.appendChild(item);
            });
            pw.dataset.loaded = "1";
          }).catch(function () { pw.textContent = "Could not load wallet activity. Try again."; });
        }
      }
    }
    if (screen === "driver-application") {
      if (isDriver(currentUser)) showDriverApp(currentUser);
      else activateAppScreen("home");
    } else {
      $("driverApp").hidden = true;
    }
    if (screen === "profile") {
      var target = driverMode ? $("driverProfileContent") : $("passengerProfileContent");
      target.innerHTML = "";
      var fields = [["Name", currentUser.display_name || [currentUser.first_name,currentUser.last_name].filter(Boolean).join(" ")],["Email",currentUser.email],["Phone", [currentUser.country_code,currentUser.contact_number].filter(Boolean).join(" ")],["Username",currentUser.username]];
      fields.forEach(function (field) {
        if (!field[1]) return;
        var row = document.createElement("div"); row.className = "profile-field";
        var label = document.createElement("span"); label.className = "muted small"; label.textContent = field[0];
        var value = document.createElement("strong"); value.textContent = field[1];
        row.append(label,value); target.appendChild(row);
      });
      if (isDriver(currentUser)) {
        var applicationLink = document.createElement("button");
        applicationLink.type = "button";
        applicationLink.className = "ghost driver-application-link";
        applicationLink.textContent = "Manage driver application";
        applicationLink.addEventListener("click", function () { activateAppScreen("driver-application"); });
        target.appendChild(applicationLink);
      }
    } else if (screen !== "driver-application") {
      $("driverApp").hidden = true;
    }
    if (screen === "trips") {
      if (driverMode) loadDriverHistory();
      else loadPassengerData();
    }
    try { history.replaceState(null, "", "#"+screen); } catch (_) {}
  }
  $("appNavigation").querySelectorAll("[data-screen]").forEach(function (button) {
    button.addEventListener("click", function () { activateAppScreen(button.getAttribute("data-screen")); });
  });
  window.addEventListener("popstate", function () {
    var screen = (window.location.hash || "#home").slice(1);
    activateAppScreen(screen);
  });

  function showWorkspaces(user) {
    var driverRole = isDriver(user);
    var approved = driverRole && user.driver_status === "approved" && user.status === "active";
    $("passengerDashboard").hidden = user.active_mode === "driver";
    $("driverDashboard").hidden = !(user.active_mode === "driver" && approved);
    $("appNavigation").hidden = false;
    if (user.active_mode !== "driver") {
      if (driverPollTimer) clearInterval(driverPollTimer);
      driverPollTimer = null;
      initRideMap();
      loadRouteStopSettings();
      loadPassengerData();
      if (!passengerPollTimer) passengerPollTimer = setInterval(loadCurrentRide, 12000);
    } else {
      if (passengerPollTimer) clearInterval(passengerPollTimer);
      passengerPollTimer = null;
      if (approved) {
        loadDriverData();
        if (!driverPollTimer) driverPollTimer = setInterval(loadDriverRequests, 6000);
      }
    }
    activateAppScreen((window.location.hash || "#home").slice(1));
  }
  function loadPassengerData() {
    loadCurrentRide();
    api("/ride/history").then(function (r) {
      if (r.status !== 200 || !r.body || r.body.status === false) return;
      var rows = r.body.data || [];
      $("rideHistory").innerHTML = "";
      if (!rows.length) { $("rideHistory").textContent = "No completed trips yet."; return; }
      rows.slice(0, 10).forEach(function (trip) {
        var item = document.createElement("article"); item.className = "history-item";
        var title = document.createElement("strong"); title.textContent = "Trip #" + trip.id + " · " + String(trip.status || "").replace(/_/g, " ");
        var detail = document.createElement("p"); detail.textContent = (trip.pickup && trip.pickup.address || "Pickup") + " → " + (trip.dropoff && trip.dropoff.address || "Destination");
        var fare = document.createElement("span"); fare.textContent = money(trip.fare, trip.currency);
        item.append(title, detail, fare); $("rideHistory").appendChild(item);
      });
    }).catch(function () {});
  }
  function loadCurrentRide() {
    api("/ride/current").then(function (r) {
      if (r.status !== 200) return;
      var trip = r.body && r.body.data;
      $("currentRide").hidden = !trip;
      if (!trip) {
        if (driverMarker) removeMapMarker(driverMarker);
        driverMarker = null;
        return;
      }
      var stopSummary = (trip.stops || []).map(function (stop, i) { return "Stop " + (i + 1) + ": " + (stop.address || "Location") + " (" + String(stop.status || "pending") + ")"; }).join(" → ");
      var summary = "Trip #" + trip.id + " · " + String(trip.status).replace(/_/g, " ") +
        " · " + (trip.pickup && trip.pickup.address || "Pickup") + (stopSummary ? " → " + stopSummary : "") + " → " + (trip.dropoff && trip.dropoff.address || "Destination") +
        " · " + money(trip.fare, trip.currency);
      if (trip.driver) {
        summary += " · Driver: " + (trip.driver.name || "Assigned");
        if (trip.driver.vehicle) summary += " · Vehicle: " + [trip.driver.vehicle.colour, trip.driver.vehicle.make, trip.driver.vehicle.model, trip.driver.vehicle.plate].filter(Boolean).join(" ");
        if (trip.driver.contact_number) summary += " · Contact: " + trip.driver.contact_number;
        if (trip.driver.location && rideMap && window.L) {
          var driverLL = [Number(trip.driver.location.lat), Number(trip.driver.location.lng)];
          if (driverLL.every(Number.isFinite)) {
            var driverIcon = mapConfig && mapConfig.vehicle_icons && trip.service && mapConfig.vehicle_icons[trip.service.map_icon];
            if (driverMarker) moveMapMarker(driverMarker, { lat: driverLL[0], lng: driverLL[1] });
            else driverMarker = createMapMarker({ lat: driverLL[0], lng: driverLL[1] }, "driver", driverIcon);
          }
        }
      } else if (driverMarker) { removeMapMarker(driverMarker); driverMarker = null; }
      $("currentRideDetails").textContent = summary;
      $("cancelRide").hidden = !["searching", "accepted", "arrived"].includes(trip.status);
    }).catch(function () {});
  }
  $("addRouteStop").addEventListener("click", function () {
    if (routeStops.length >= maxRouteStops) return;
    routeStops.push({ point: null, address: "", marker: null });
    renderRouteStops(); updateSelectedCoords(); invalidateRideQuote();
    var radios = $("routeStops").querySelectorAll('input[name="mapTarget"]');
    if (radios.length) radios[radios.length - 1].checked = true;
    setPassengerMessage("Tap the map to place Stop " + routeStops.length + ".", "ok");
  });
  $("useMyLocation").addEventListener("click", function () {
    var msg = $("locationMsg");
    if (!navigator.geolocation) { msg.textContent = "Location is not supported by this browser."; return; }
    msg.textContent = "Getting your location…";
    navigator.geolocation.getCurrentPosition(function (pos) {
      var ll = { lat: pos.coords.latitude, lng: pos.coords.longitude };
      setPoint("pickup", ll);
      if (rideMap) setMapView(ll, 15);
      msg.textContent = "Pickup set to your current location.";
    }, function () { msg.textContent = "Location permission was denied or unavailable. Tap the map to choose pickup."; }, { enableHighAccuracy: true, timeout: 12000, maximumAge: 30000 });
  });
  $("getEstimate").addEventListener("click", function () {
    if (!pickupPoint || !dropoffPoint) { setPassengerMessage("Choose both pickup and destination on the map first.", "err"); return; }
    var stops = routeStopPayload(); if (stops === null) return;
    var btn = $("getEstimate"); btn.disabled = true; setPassengerMessage("Calculating fares for the complete route…");
    api("/ride/estimate", { method: "POST", body: JSON.stringify({
      pickup: Object.assign({}, pickupPoint, { address: $("pickupAddress").value.trim() }),
      dropoff: Object.assign({}, dropoffPoint, { address: $("dropoffAddress").value.trim() }),
      stops: stops
    }) }).then(function (r) {
      if (r.status !== 200 || !r.body || r.body.status !== true) throw new Error(r.body && r.body.message || "Could not estimate this trip.");
      lastQuote = r.body; selectedRideType = null;
      var box = $("fareOptions"); box.innerHTML = "";
      (r.body.ride_types || []).forEach(function (type) {
        var card = document.createElement("button"); card.type = "button"; card.className = "ride-option";
        card.innerHTML = "";
        var name = document.createElement("strong"); name.textContent = type.name + (type.badge ? " · " + type.badge : "");
        var info = document.createElement("span"); info.textContent = money(type.fare, r.body.currency) + " · " + type.capacity + " seats";
        var nearby = document.createElement("small"); nearby.textContent = type.drivers_nearby + " nearby drivers";
        card.append(name, info, nearby);
        card.addEventListener("click", function () {
          selectedRideType = type;
          Array.prototype.forEach.call(box.children, function (el) { el.classList.remove("selected"); });
          card.classList.add("selected");
          var payment = $("ridePayment"); payment.innerHTML = "";
          (type.payment_methods || []).filter(function (m) { return ["cash", "wallet"].includes(m); }).forEach(function (m) {
            var op = document.createElement("option"); op.value = m; op.textContent = m.replace(/_/g, " "); payment.appendChild(op);
          });
          $("requestRideWrap").hidden = !payment.options.length;
        });
        box.appendChild(card);
      });
      if (!box.children.length) throw new Error("No ride types are available for this trip right now.");
      var routeDistance = Number(r.body.distance || 0).toFixed(1) + " " + (r.body.distance_unit || "km");
      setPassengerMessage("Fare estimate ready · " + routeDistance + " · " + Number(r.body.duration_minutes || 0) + " min for the complete route. Select a ride type to continue.", "ok");
    }).catch(function (e) { setPassengerMessage(e.message, "err"); })
      .finally(function () { btn.disabled = false; });
  });
  $("requestRide").addEventListener("click", function () {
    if (!selectedRideType || !lastQuote) return;
    var stops = routeStopPayload(); if (stops === null) return;
    var btn = $("requestRide"); btn.disabled = true; setPassengerMessage("Requesting your ride…");
    api("/ride/request", { method: "POST", body: JSON.stringify({
      pickup: Object.assign({}, pickupPoint, { address: $("pickupAddress").value.trim() }),
      dropoff: Object.assign({}, dropoffPoint, { address: $("dropoffAddress").value.trim() }),
      stops: stops,
      service_id: selectedRideType.id, payment_method: $("ridePayment").value, option_ids: []
    }) }).then(function (r) {
      if (r.status !== 201 && !(r.status === 200 && r.body && r.body.status)) throw new Error(r.body && r.body.message || "Ride request failed.");
      setPassengerMessage("Ride requested. We are finding a driver.", "ok");
      $("requestRideWrap").hidden = true; loadCurrentRide();
    }).catch(function (e) { setPassengerMessage(e.message, "err"); })
      .finally(function () { btn.disabled = false; });
  });
  $("cancelRide").addEventListener("click", function () {
    if (!window.confirm("Cancel this ride request?")) return;
    api("/ride/cancel", { method: "POST", body: JSON.stringify({ reason: "Cancelled by passenger" }) })
      .then(function (r) { if (!r.body || r.body.status !== true) throw new Error(r.body && r.body.message || "Could not cancel this ride."); setPassengerMessage("Ride cancelled.", "ok"); loadCurrentRide(); loadPassengerData(); })
      .catch(function (e) { setPassengerMessage(e.message, "err"); });
  });
  $("passengerRefresh").addEventListener("click", loadPassengerData);

  function loadDriverData() {
    api("/driver/status").then(function (r) {
      if (r.status !== 200) throw new Error(r.body && r.body.message || "Driver status unavailable.");
      driverOnline = r.body.is_online === true;
      $("driverOnlineLabel").textContent = driverOnline ? "Online" : "Offline";
      $("driverOnlineToggle").textContent = driverOnline ? "Go offline" : "Go online";
      var w = r.body.wallet || {};
      $("driverEligibility").textContent = "Wallet: " + money(w.balance, { code: "NGN" }) + " · Minimum: " + money(w.minimum, { code: "NGN" }) +
        (r.body.online_block && r.body.online_block.message ? " · " + r.body.online_block.message : "");
      loadDriverRequests(); loadDriverHistory();
    }).catch(function (e) { setMsg($("driverMsg"), e.message, "err"); });
  }
  function loadDriverRequests() {
    api("/driver/requests").then(function (r) {
      var box = $("driverRequests"); box.innerHTML = "";
      if (r.status !== 200 || !r.body || r.body.status === false) {
        box.textContent = r.body && r.body.message || "No requests available. Go online when you're ready.";
        return;
      }
      var active = r.body.active;
      if (active) {
        var a = document.createElement("article"); a.className = "history-item";
        var h = document.createElement("strong"); h.textContent = "Trip #" + active.id + " · " + active.status.replace(/_/g, " ");
        var stops = Array.isArray(active.stops) ? active.stops : [];
        var route = [active.pickup.address || "Pickup"].concat(stops.map(function (stop) { return stop.address || ("Stop " + stop.sequence); })).concat([active.dropoff.address || "Destination"]);
        var d = document.createElement("p"); d.textContent = route.join(" → ") + " · " + money(active.fare, {code:"NGN"});
        a.append(h, d);
        if (stops.length) {
          var list = document.createElement("ol"); list.className = "driver-stop-list";
          stops.forEach(function (stop, i) {
            var li = document.createElement("li"); li.textContent = "Stop " + (i + 1) + ": " + (stop.address || "Pinned location") + " — " + String(stop.status || "pending");
            list.appendChild(li);
          });
          a.appendChild(list);
        }
        var actions = document.createElement("div"); actions.className = "driver-actions";
        var steps = active.status === "accepted" ? [["arrived","I've arrived"]] : active.status === "arrived" ? [["start","Start trip"]] : [];
        if (active.status === "in_progress") {
          var nextStop = stops.find(function (stop) { return stop.status !== "completed"; });
          if (nextStop && nextStop.status === "pending") steps.push(["stops/" + nextStop.id + "/arrived", "Arrived at stop " + nextStop.sequence]);
          else if (nextStop && nextStop.status === "arrived") steps.push(["stops/" + nextStop.id + "/complete", "Complete stop " + nextStop.sequence]);
          else steps.push(["complete", "Complete trip"]);
        }
        steps.forEach(function (step) {
          var b = document.createElement("button"); b.type = "button"; b.className = "primary"; b.textContent = step[1];
          b.addEventListener("click", function () { driverAction("/driver/rides/" + active.id + "/" + step[0], "POST", {}); });
          actions.appendChild(b);
        });
        if (["accepted", "arrived"].includes(active.status)) {
          var cancel = document.createElement("button"); cancel.type = "button"; cancel.className = "ghost"; cancel.textContent = "Release this request";
          cancel.addEventListener("click", function () {
            if (window.confirm("Release this request? It will return to the nearby driver pool.")) driverAction("/driver/rides/" + active.id + "/cancel", "POST", {});
          });
          actions.appendChild(cancel);
        }
        a.appendChild(actions); box.appendChild(a); return;
      }
      var rows = r.body.requests || [];
      if (!rows.length) { box.textContent = "No nearby ride requests at the moment."; return; }
      rows.forEach(function (req) {
        var a = document.createElement("article"); a.className = "history-item";
        var h = document.createElement("strong"); h.textContent = "Request #" + req.id + " · " + money(req.fare, {code:"NGN"});
        var route = [req.pickup.address || "Pickup"].concat((req.stops || []).map(function (stop) { return stop.address || "Additional stop"; })).concat([req.dropoff.address || "Destination"]);
        var d = document.createElement("p"); d.textContent = route.join(" → ") + " · " + req.pickup_distance_km + " km away";
        var actions = document.createElement("div"); actions.className = "driver-actions";
        [["accept","Accept"],["decline","Decline"]].forEach(function (act) {
          var b = document.createElement("button"); b.type = "button"; b.className = act[0] === "accept" ? "primary" : "ghost"; b.textContent = act[1];
          b.addEventListener("click", function () { driverAction("/driver/requests/" + req.id + "/" + act[0], "POST", {}); });
          actions.appendChild(b);
        });
        a.append(h, d, actions); box.appendChild(a);
      });
    }).catch(function (e) { setMsg($("driverMsg"), e.message, "err"); });
  }
  function driverAction(path, method, body) {
    api(path, { method: method, body: JSON.stringify(body || {}) }).then(function (r) {
      if (r.status < 200 || r.status >= 300 || (r.body && r.body.status === false)) throw new Error(r.body && r.body.message || "That action could not be completed.");
      setMsg($("driverMsg"), "Updated.", "ok"); loadDriverData();
    }).catch(function (e) { setMsg($("driverMsg"), e.message, "err"); });
  }
  function loadDriverHistory() {
    api("/driver/rides/history").then(function (r) {
      var box = $("driverHistory"); box.innerHTML = "";
      (r.body && r.body.data || []).slice(0, 10).forEach(function (trip) {
        var item = document.createElement("article"); item.className = "history-item";
        var h = document.createElement("strong"); h.textContent = "Trip #" + trip.id + " · " + money(trip.earning, {code:"NGN"}) + " earned";
        var d = document.createElement("p"); d.textContent = (trip.pickup_address || "Pickup") + " → " + (trip.dropoff_address || "Destination");
        item.append(h, d); box.appendChild(item);
      });
      if (!box.children.length) box.textContent = "No completed trips yet.";
    }).catch(function () {});
  }
  $("driverOnlineToggle").addEventListener("click", function () {
    var online = !driverOnline, btn = $("driverOnlineToggle"); btn.disabled = true;
    function send(pos) {
      var body = { online: online };
      if (online) { body.latitude = pos.coords.latitude; body.longitude = pos.coords.longitude; }
      driverAction("/driver/online", "POST", body);
      btn.disabled = false;
    }
    if (!online) { send(null); driverOnline = false; $("driverOnlineLabel").textContent = "Offline"; $("driverOnlineToggle").textContent = "Go online"; return; }
    if (!navigator.geolocation) { setMsg($("driverMsg"), "Location is required to go online.", "err"); btn.disabled = false; return; }
    navigator.geolocation.getCurrentPosition(send, function () {
      setMsg($("driverMsg"), "Allow location access to go online.", "err"); btn.disabled = false;
    }, { enableHighAccuracy: true, timeout: 12000 });
  });
  $("driverRefresh").addEventListener("click", loadDriverData);
  function refreshDriverLocation() {
    if (!driverOnline || !navigator.geolocation) return;
    navigator.geolocation.getCurrentPosition(function (p) {
      api("/driver/location", { method: "POST", body: JSON.stringify({ latitude: p.coords.latitude, longitude: p.coords.longitude }) }).catch(function () {});
    }, function () {}, { maximumAge: 20000, timeout: 8000 });
  }
  setInterval(refreshDriverLocation, 30000);

  checkSession();
})();
