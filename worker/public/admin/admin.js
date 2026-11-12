// Drop Admin. Plain JavaScript, no dependencies. All data is inserted with textContent (never innerHTML).
(function () {
  "use strict";
  var $ = function (id) { return document.getElementById(id); };
  var TOKEN = null, ME = null;
  try { TOKEN = sessionStorage.getItem("drop_admin_token"); } catch (e) {}

  // ---------- helpers ----------
  function h(tag, attrs) {
    var n = document.createElement(tag);
    Object.keys(attrs || {}).forEach(function (k) {
      var v = attrs[k];
      if (v === null || v === undefined || v === false) return;
      if (k === "text") n.textContent = v;
      else if (k === "class") n.className = v;
      else if (k === "on") Object.keys(v).forEach(function (ev) { n.addEventListener(ev, v[ev]); });
      else if (k === "value") n.value = v;
      else if (k === "checked") n.checked = !!v;
      else n.setAttribute(k, v === true ? "" : v);
    });
    for (var i = 2; i < arguments.length; i++) {
      var c = arguments[i];
      if (c === null || c === undefined || c === false) continue;
      if (Array.isArray(c)) c.forEach(function (x) { if (x) n.appendChild(x); });
      else n.appendChild(typeof c === "string" ? document.createTextNode(c) : c);
    }
    return n;
  }
  function can(p) { return !!ME && ME.permissions.indexOf(p) !== -1; }
  function saveToken(t) { TOKEN = t; try { t ? sessionStorage.setItem("drop_admin_token", t) : sessionStorage.removeItem("drop_admin_token"); } catch (e) {} }
  function msg(el, text, ok) { el.textContent = text || ""; el.className = "msg " + (text ? (ok ? "ok" : "err") : ""); }
  var toastTimer;
  function toast(text, bad) {
    var t = h("div", { class: "toast" + (bad ? " err" : ""), text: text });
    document.body.appendChild(t); clearTimeout(toastTimer);
    toastTimer = setTimeout(function () { t.remove(); }, 2600);
  }
  function naira(v) { return v === null || v === undefined ? "-" : "₦" + Number(v).toLocaleString("en-NG", { maximumFractionDigits: 2 }); }

  function api(method, path, body) {
    return fetch("/api" + path, {
      method: method,
      headers: Object.assign({ Accept: "application/json" }, body ? { "Content-Type": "application/json" } : {}, TOKEN ? { Authorization: "Bearer " + TOKEN } : {}),
      body: body ? JSON.stringify(body) : undefined
    }).then(function (r) {
      return r.json().catch(function () { return {}; }).then(function (j) {
        if (r.status === 401) { signedOut(); }
        return { status: r.status, ok: r.ok, body: j };
      });
    }).catch(function () { return { status: 0, ok: false, body: { message: "Network error. Try again." } }; });
  }
  function errText(r) {
    var b = r.body || {};
    if (b.errors) { var k = Object.keys(b.errors)[0]; return (k && k !== "body" ? k.replace(/_/g, " ") + ": " : "") + b.errors[k][0]; }
    return b.message || "Something went wrong.";
  }

  // ---------- signed-out screens ----------
  function showAuth(which) {
    $("app").hidden = true; $("authWrap").hidden = false;
    $("login").hidden = which !== "login"; $("setup").hidden = which !== "setup";
  }
  function signedOut() { saveToken(null); ME = null; showAuth("login"); }

  $("loginForm").addEventListener("submit", function (e) {
    e.preventDefault();
    var btn = $("loginBtn"); btn.disabled = true; msg($("loginMsg"), "");
    api("POST", "/login", { email: $("email").value, password: $("password").value, user_type: "admin" }).then(function (r) {
      btn.disabled = false;
      if (r.body && r.body.status === true && r.body.data) { saveToken(r.body.data.api_token); $("password").value = ""; start(); }
      else msg($("loginMsg"), (r.body && r.body.message) || "Could not sign in.");
    });
  });
  $("setupLink").addEventListener("click", function (e) { e.preventDefault(); showAuth("setup"); });
  $("backLogin").addEventListener("click", function (e) { e.preventDefault(); showAuth("login"); });
  $("setupForm").addEventListener("submit", function (e) {
    e.preventDefault(); msg($("setupMsg"), "");
    api("POST", "/admin/bootstrap", {
      token: $("s_token").value, first_name: $("s_first").value, last_name: $("s_last").value,
      username: $("s_user").value, email: $("s_email").value, password: $("s_pass").value
    }).then(function (r) {
      if (r.status === 200 && r.body.api_token) { saveToken(r.body.api_token); $("s_token").value = ""; $("s_pass").value = ""; start(); }
      else if (r.status === 404) msg($("setupMsg"), "Setup is not available (already done, or the setup code is wrong).");
      else msg($("setupMsg"), errText(r));
    });
  });
  $("logout").addEventListener("click", function () { api("GET", "/logout").then(signedOut); });

  // ---------- shell ----------
  var PAGES = [
    { id: "documents", label: "Document types", group: "People", perm: "document list", render: pageDocuments },
    { id: "driver-applications", label: "Driver applications", group: "People", perm: "driver_application list", render: pageDriverApplications },
    { id: "ride-types", label: "Ride types", group: "Operations", perm: "service list", render: pageRideTypes },
    { id: "maps", label: "Maps", group: "Operations", perm: "map_settings list", render: pageMaps },
    { id: "regions", label: "Regions", group: "Operations", perm: "region list", render: pageRegions },
    { id: "ride-options", label: "Ride options", group: "Operations", perm: "service_option list", render: pageOptions },
    { id: "payment-methods", label: "Payment methods", group: "Financial", perm: "payment_gateway list", render: pagePayments },
    { id: "transfers", label: "Wallet transfers", group: "Financial", perm: "wallet_transfer list", render: pageTransfers },
    { id: "paymyride", label: "PayMyRide", group: "Financial", perm: "paymyride list", render: pagePayMyRide },
    { id: "banks", label: "Banks", group: "Financial", perm: "bank list", render: pageBanks },
    { id: "driver-wallets", label: "Driver wallets", group: "Financial", perm: "driver_wallet list", render: pageDriverWallets },
    { id: "user-accounts", label: "User accounts", group: "People", perm: "user_account list", render: pageUserAccounts },
    { id: "roles", label: "Roles", group: "System", perm: "role list", render: pageRoles },
    { id: "sub-admins", label: "Sub-admins", group: "System", perm: "subadmin list", render: pageSubAdmins }
  ];
  function setNav(open) { document.body.classList.toggle("nav-open", open); }
  $("menuBtn").addEventListener("click", function () { setNav(true); });
  $("scrim").addEventListener("click", function () { setNav(false); });

  function start() {
    api("GET", "/admin/me").then(function (r) {
      if (!r.ok) { if (r.status === 403) { saveToken(null); showAuth("login"); msg($("loginMsg"), "This account is not an administrator."); } else showAuth("login"); return; }
      ME = r.body;
      $("authWrap").hidden = true; $("app").hidden = false;
      $("who").textContent = (ME.name || "") + " · " + ME.email;
      var nav = $("navLinks"); nav.textContent = ""; var last = null;
      PAGES.forEach(function (p) {
        if (!can(p.perm)) return;
        if (p.group !== last) { nav.appendChild(h("div", { class: "group", text: p.group })); last = p.group; }
        nav.appendChild(h("a", { href: "#/" + p.id, "data-page": p.id, text: p.label }));
      });
      route();
    });
  }

  function route() {
    if (!ME) return;
    var id = (location.hash.replace(/^#\/?/, "") || "").split("/")[0];
    var page = PAGES.filter(function (p) { return p.id === id && can(p.perm); })[0] || PAGES.filter(function (p) { return can(p.perm); })[0];
    var links = document.querySelectorAll("#navLinks a");
    Array.prototype.forEach.call(links, function (a) { a.classList.toggle("active", page && a.getAttribute("data-page") === page.id); });
    setNav(false);
    // Each visit gets a fresh container, so a slow response from a page you already left cannot draw over this one.
    var holder = $("page"); holder.textContent = "";
    var root = h("div"); holder.appendChild(root);
    if (!page) { root.appendChild(h("div", { class: "card" }, h("h2", { text: "No access yet" }), h("p", { class: "muted", text: "Your role has no permissions. Ask a super admin to update it." }))); return; }
    $("title").textContent = page.label;
    page.render(root);
  }
  window.addEventListener("hashchange", route);

  // ---------- reusable bits ----------
  function sw(checked, onChange) {
    var input = h("input", { type: "checkbox", checked: checked });
    input.addEventListener("change", function () { onChange(input.checked, input); });
    return h("label", { class: "switch" }, input, h("span"));
  }
  function field(label, input, hint) { return h("div", {}, h("label", { class: "f", text: label }), input, hint ? h("div", { class: "hint", text: hint }) : null); }
  function text(v, ph) { return h("input", { type: "text", value: v == null ? "" : v, placeholder: ph || "" }); }
  function num(v, ph) { return h("input", { type: "number", step: "any", inputmode: "decimal", value: v == null ? "" : v, placeholder: ph || "" }); }
  function select(opts, v) {
    var s = h("select");
    opts.forEach(function (o) { s.appendChild(h("option", { value: o[0], text: o[1] })); });
    s.value = v == null ? "" : String(v); return s;
  }
  /** A row of tick pills. Returns { el, get() }. */
  function checks(opts, selected) {
    var box = h("div", { class: "checks" }); var inputs = {};
    opts.forEach(function (o) {
      var i = h("input", { type: "checkbox", checked: selected.indexOf(o[0]) !== -1 });
      var l = h("label", { class: "chk" + (i.checked ? " on" : "") }, i, o[1]);
      i.addEventListener("change", function () { l.classList.toggle("on", i.checked); });
      inputs[o[0]] = i; box.appendChild(l);
    });
    return { el: box, get: function () { return opts.map(function (o) { return o[0]; }).filter(function (k) { return inputs[k].checked; }); } };
  }
  function nn(el) { var v = el.value.trim(); return v === "" ? null : Number(v); }
  function ns(el) { var v = el.value.trim(); return v === "" ? null : v; }
  function confirmDo(text, fn) { if (window.confirm(text)) fn(); }
  function head(title, sub, right) {
    return h("div", { class: "bar" }, h("div", { class: "grow" }, h("h2", { text: title }), sub ? h("div", { class: "muted", text: sub }) : null), right || null);
  }
  function loading(root) { root.textContent = ""; root.appendChild(h("div", { class: "empty", text: "Loading…" })); }

  // ---------- Ride types ----------
  var rt = { region: "", regions: [] };
  var CATEGORIES = [["car", "Car"], ["bike", "Bike"], ["tricycle", "Tricycle"], ["bus", "Bus or van"], ["van", "Van"], ["delivery", "Delivery"], ["other", "Other"]];
  var BOOKING = [["now", "Book now"], ["scheduled", "Scheduled"], ["multi_drop", "Multi-drop"], ["bidding", "Bidding"], ["for_other", "For someone else"]];
  var PAYMENTS = [["cash", "Cash"], ["wallet", "Wallet"], ["card", "Card"], ["virtual_account", "Virtual account"]];

  function pageRideTypes(root) {
    loading(root);
    var regionsReq = can("region list") ? api("GET", "/admin/regions") : Promise.resolve({ body: { data: [] } });
    Promise.all([regionsReq, api("GET", "/admin/services" + (rt.region ? "?region_id=" + rt.region : ""))]).then(function (res) {
      rt.regions = (res[0].body && res[0].body.data) || [];
      var list = (res[1].body && res[1].body.data) || [];
      root.textContent = "";
      var regionSel = select([["", "All regions"]].concat(rt.regions.map(function (r) { return [r.id, r.name || ("Region " + r.id)]; })), rt.region);
      regionSel.addEventListener("change", function () { rt.region = regionSel.value; pageRideTypes(root); });
      root.appendChild(head("Ride types", "Add, price, switch on or off and reorder what passengers can book.",
        can("service add") ? h("button", { text: "Add ride type", on: { click: function () { rideTypeForm(root, null); } } }) : null));
      root.appendChild(h("div", { class: "card" }, field("Region", regionSel)));

      var card = h("div", { class: "card" });
      if (!list.length) {
        card.appendChild(h("div", { class: "empty", text: rt.regions.length ? "No ride types here yet." : "Add a region first, then its ride types." }));
        if (rt.region && can("service add")) {
          card.appendChild(h("p", { style: "text-align:center" }, h("button", { text: "Add the starter set", on: { click: function () {
            api("POST", "/admin/regions/" + rt.region + "/starter-ride-types").then(function (r) { toast(r.ok ? r.body.message : errText(r), !r.ok); pageRideTypes(root); });
          } } })));
          card.appendChild(h("p", { class: "muted", style: "text-align:center", text: "Adds Go, Comfort, XL, Premium, Bike, Keke, Shuttle and more, all switched off with placeholder fares for you to review." }));
        }
      }
      list.forEach(function (s, i) {
        var acts = h("div", { class: "acts" });
        if (can("service edit") && list.length > 1) {
          acts.appendChild(h("button", { class: "ghost small", text: "↑", "aria-label": "Move up", disabled: i === 0, on: { click: function () { move(list, i, -1, root); } } }));
          acts.appendChild(h("button", { class: "ghost small", text: "↓", "aria-label": "Move down", disabled: i === list.length - 1, on: { click: function () { move(list, i, 1, root); } } }));
        }
        if (can("service edit")) acts.appendChild(h("button", { class: "ghost small", text: "Edit", on: { click: function () { rideTypeForm(root, s.id); } } }));
        if (can("service add") && rt.regions.length > 1) acts.appendChild(h("button", { class: "ghost small", text: "Copy", on: { click: function () { copyTo(s, root); } } }));
        if (can("service delete")) acts.appendChild(h("button", { class: "danger small", text: "Delete", on: { click: function () {
          confirmDo("Delete " + s.name + "?", function () { api("DELETE", "/admin/services/" + s.id).then(function (r) { toast(r.ok ? "Deleted" : errText(r), !r.ok); if (r.ok) pageRideTypes(root); }); });
        } } }));
        var sub = [s.category, s.capacity + " seat" + (s.capacity === 1 ? "" : "s"), "from " + naira(s.base_fare), s.region_name].filter(Boolean).join(" · ");
        card.appendChild(h("div", { class: "item" },
          h("div", { class: "main" }, h("div", { class: "t", text: s.name + (s.badge ? "  · " + s.badge : "") }), h("div", { class: "s", text: sub }), h("div", { style: "margin-top:8px" }, acts)),
          can("service edit") ? sw(s.status, function (on, input) {
            api("PUT", "/admin/services/" + s.id + "/status", { status: on }).then(function (r) { if (!r.ok) { input.checked = !on; toast(errText(r), true); } });
          }) : h("span", { class: "pill " + (s.status ? "on" : ""), text: s.status ? "On" : "Off" })
        ));
      });
      root.appendChild(card);
    });
  }
  function move(list, i, d, root) {
    var ids = list.map(function (s) { return s.id; });
    var t = ids[i]; ids[i] = ids[i + d]; ids[i + d] = t;
    api("PUT", "/admin/services-order", { ids: ids }).then(function (r) { if (!r.ok) toast(errText(r), true); pageRideTypes(root); });
  }
  function copyTo(s, root) {
    var others = rt.regions.filter(function (r) { return r.id !== s.region_id; });
    var pick = window.prompt("Copy \"" + s.name + "\" to which region? Type a number:\n" + others.map(function (r, i) { return (i + 1) + ". " + r.name; }).join("\n"));
    var r = others[Number(pick) - 1]; if (!r) return;
    api("POST", "/admin/services/" + s.id + "/duplicate", { region_id: r.id }).then(function (x) { toast(x.ok ? "Copied to " + r.name + " (switched off)" : errText(x), !x.ok); });
  }

  function rideTypeForm(root, id) {
    loading(root);
    var one = id ? api("GET", "/admin/services/" + id) : Promise.resolve({ body: { data: {} } });
    one.then(function (r) {
      var s = (r.body && r.body.data) || {};
      if (id && !r.ok) { toast("Ride type not found", true); return pageRideTypes(root); }
      var i18n = s.name_i18n || {}, hrs = s.working_hours;
      var f = {
        name: text(s.name), region_id: select(rt.regions.map(function (g) { return [g.id, g.name]; }), s.region_id || rt.region || (rt.regions[0] && rt.regions[0].id)),
        category: select(CATEGORIES, s.category || "car"), capacity: num(s.capacity == null ? 4 : s.capacity),
        description: text(s.description), icon_url: text(s.icon_url, "https://…"), photo_url: text(s.photo_url, "https://…"),
        ha: text(i18n.ha), yo: text(i18n.yo), ig: text(i18n.ig), pcm: text(i18n.pcm),
        base_fare: num(s.base_fare), minimum_fare: num(s.minimum_fare), minimum_distance: num(s.minimum_distance),
        per_distance: num(s.per_distance), per_minute_drive: num(s.per_minute_drive), per_minute_wait: num(s.per_minute_wait),
        waiting_time_limit: num(s.waiting_time_limit), cancellation_fee: num(s.cancellation_fee),
        commission_type: select([["percentage", "Percentage"], ["fixed", "Fixed amount"]], s.commission_type || "percentage"),
        admin_commission: num(s.admin_commission == null ? 15 : s.admin_commission), fleet_commission: num(s.fleet_commission == null ? 0 : s.fleet_commission),
        booking: checks(BOOKING, s.booking_modes || ["now"]), payments: checks(PAYMENTS, s.payment_methods || ["cash", "wallet"]),
        min_driver_rating: num(s.min_driver_rating), min_wallet_balance: num(s.min_wallet_balance),
        limit_hours: h("input", { type: "checkbox", checked: !!hrs }), from: h("input", { type: "time", value: hrs ? hrs.from : "06:00" }), to: h("input", { type: "time", value: hrs ? hrs.to : "22:00" }),
        badge: text(s.badge, "New, Popular…"), sort_order: num(s.sort_order || 0), status: h("input", { type: "checkbox", checked: s.status !== false && !!id ? s.status : false })
      };
      var out = h("p", { class: "msg" });
      root.textContent = "";
      root.appendChild(head(id ? "Edit ride type" : "Add ride type", null, h("button", { class: "ghost", text: "Back", on: { click: function () { pageRideTypes(root); } } })));
      var card = h("div", { class: "card" });
      card.appendChild(h("h3", { text: "Basics" }));
      card.appendChild(field("Name", f.name));
      card.appendChild(h("div", { class: "grid2" }, field("Region", f.region_id), field("Category", f.category)));
      card.appendChild(h("div", { class: "grid2" }, field("Seats or load capacity", f.capacity), field("Badge", f.badge)));
      card.appendChild(field("Short description", f.description));
      card.appendChild(h("div", { class: "grid2" }, field("Icon link", f.icon_url), field("Photo link", f.photo_url)));
      card.appendChild(h("h3", { text: "Name in other languages" }));
      card.appendChild(h("div", { class: "grid2" }, field("Hausa", f.ha), field("Yoruba", f.yo), field("Igbo", f.ig), field("Pidgin", f.pcm)));
      card.appendChild(h("h3", { text: "Fare (₦)" }));
      card.appendChild(h("div", { class: "grid2" }, field("Base fare", f.base_fare), field("Minimum fare", f.minimum_fare), field("Minimum distance", f.minimum_distance), field("Per distance", f.per_distance),
        field("Per minute driving", f.per_minute_drive), field("Per minute waiting", f.per_minute_wait), field("Free waiting (minutes)", f.waiting_time_limit), field("Cancellation fee", f.cancellation_fee)));
      card.appendChild(h("h3", { text: "Commission" }));
      card.appendChild(h("div", { class: "grid2" }, field("Type", f.commission_type), field("DROP share", f.admin_commission), field("Fleet share", f.fleet_commission)));
      card.appendChild(h("h3", { text: "Booking and payment" }));
      card.appendChild(field("Booking modes", f.booking.el));
      card.appendChild(field("Payment methods allowed", f.payments.el, "Cash and wallet work in the shipped apps today. Card and virtual account follow with the native payment screens."));
      card.appendChild(h("h3", { text: "Driver rules" }));
      card.appendChild(h("div", { class: "grid2" }, field("Minimum driver rating (0-5)", f.min_driver_rating), field("Minimum wallet balance (₦)", f.min_wallet_balance, "Blocks new trips below this. Can be negative.")));
      card.appendChild(h("h3", { text: "Availability" }));
      card.appendChild(h("label", { class: "chk", style: "margin-top:10px" }, f.limit_hours, "Only available between set hours"));
      card.appendChild(h("div", { class: "grid2" }, field("From", f.from), field("To", f.to)));
      card.appendChild(field("Display order (lowest first)", f.sort_order));
      card.appendChild(h("div", { class: "row" }, h("div", { text: "Available to passengers" }), h("label", { class: "switch" }, f.status, h("span"))));
      card.appendChild(out);
      var save = h("button", { text: id ? "Save changes" : "Add ride type", style: "width:100%;margin-top:14px" });
      save.addEventListener("click", function () {
        var names = {}; ["ha", "yo", "ig", "pcm"].forEach(function (k) { if (f[k].value.trim()) names[k] = f[k].value.trim(); });
        var body = {
          name: f.name.value.trim(), region_id: Number(f.region_id.value), category: f.category.value, capacity: Number(f.capacity.value || 1),
          description: ns(f.description), icon_url: ns(f.icon_url), photo_url: ns(f.photo_url), name_i18n: names,
          base_fare: nn(f.base_fare) || 0, minimum_fare: nn(f.minimum_fare) || 0, minimum_distance: nn(f.minimum_distance) || 0, per_distance: nn(f.per_distance) || 0,
          per_minute_drive: nn(f.per_minute_drive) || 0, per_minute_wait: nn(f.per_minute_wait) || 0, waiting_time_limit: nn(f.waiting_time_limit) || 0, cancellation_fee: nn(f.cancellation_fee) || 0,
          commission_type: f.commission_type.value, admin_commission: nn(f.admin_commission) || 0, fleet_commission: nn(f.fleet_commission) || 0,
          booking_modes: f.booking.get(), payment_methods: f.payments.get(),
          min_driver_rating: nn(f.min_driver_rating), min_wallet_balance: nn(f.min_wallet_balance),
          working_hours: f.limit_hours.checked ? { from: f.from.value, to: f.to.value } : null,
          badge: ns(f.badge), sort_order: Number(f.sort_order.value || 0), status: f.status.checked
        };
        if (!id) body.description_i18n = {};
        if (!body.name) return msg(out, "Enter a name.");
        if (!body.region_id) return msg(out, "Pick a region.");
        if (!body.booking_modes.length) return msg(out, "Pick at least one booking mode.");
        if (!body.payment_methods.length) return msg(out, "Pick at least one payment method.");
        save.disabled = true; msg(out, "");
        api(id ? "PUT" : "POST", "/admin/services" + (id ? "/" + id : ""), body).then(function (r) {
          save.disabled = false;
          if (r.ok) { toast("Saved"); rt.region = String(body.region_id); pageRideTypes(root); } else msg(out, errText(r));
        });
      });
      card.appendChild(save);
      root.appendChild(card);
    });
  }

  // ---------- Regions ----------
  function pageRegions(root) {
    loading(root);
    api("GET", "/admin/regions").then(function (r) {
      var list = (r.body && r.body.data) || [];
      root.textContent = "";
      root.appendChild(head("Regions", "The areas where Drop operates.", can("region add") ? h("button", { text: "Add region", on: { click: function () { regionForm(root, null); } } }) : null));
      var card = h("div", { class: "card" });
      if (!list.length) card.appendChild(h("div", { class: "empty", text: "No regions yet. Add your first operating area." }));
      list.forEach(function (g) {
        var acts = h("div", { class: "acts" });
        if (can("region edit")) acts.appendChild(h("button", { class: "ghost small", text: "Edit", on: { click: function () { regionForm(root, g); } } }));
        if (can("region delete")) acts.appendChild(h("button", { class: "danger small", text: "Delete", on: { click: function () {
          confirmDo("Delete region " + g.name + "?", function () { api("DELETE", "/admin/regions/" + g.id).then(function (x) { toast(x.ok ? "Deleted" : errText(x), !x.ok); if (x.ok) pageRegions(root); }); });
        } } }));
        card.appendChild(h("div", { class: "item" },
          h("div", { class: "main" }, h("div", { class: "t", text: g.name || "Region " + g.id }),
            h("div", { class: "s", text: g.ride_types + " ride type" + (g.ride_types === 1 ? "" : "s") + " · " + String(g.currency || "NGN").trim() + " · " + g.timezone + " · " + g.distance_unit + (g.coordinates ? " · boundary set" : " · no boundary") }),
            h("div", { style: "margin-top:8px" }, acts)),
          h("span", { class: "pill " + (g.status ? "on" : ""), text: g.status ? "On" : "Off" })));
      });
      root.appendChild(card);
    });
  }
  function regionForm(root, g) {
    var pts = (g && g.coordinates || []).map(function (p) { return p.lat + ", " + p.lng; }).join("\n");
    var f = {
      name: text(g && g.name), unit: select([["km", "Kilometres"], ["mile", "Miles"]], g ? g.distance_unit : "km"),
      tz: text(g ? g.timezone : "Africa/Lagos"), cur: select(CURRENCY_OPTIONS, g ? String(g.currency || "NGN").trim() : "NGN"), poly: h("textarea", { placeholder: "9.0765, 7.3986\n9.1000, 7.4500\n9.0400, 7.5000" }),
      status: h("input", { type: "checkbox", checked: g ? g.status : true })
    };
    f.poly.value = pts;
    var out = h("p", { class: "msg" });
    root.textContent = "";
    root.appendChild(head(g ? "Edit region" : "Add region", null, h("button", { class: "ghost", text: "Back", on: { click: function () { pageRegions(root); } } })));
    var card = h("div", { class: "card" },
      field("Name", f.name), h("div", { class: "grid2" }, field("Distance unit", f.unit), field("Time zone", f.tz)), field("Currency", f.cur, "Fares in this region are in this currency. Enter the ride type prices in it. Passengers pay from their wallet only when their wallet is in the same currency; otherwise they pay cash."),
      field("Boundary points (optional)", f.poly, "One point per line as latitude, longitude. At least 3. Drawing the boundary on a map comes with the Google Maps step."),
      h("div", { class: "row" }, h("div", { text: "Region is active" }), h("label", { class: "switch" }, f.status, h("span"))), out);
    var save = h("button", { text: "Save", style: "width:100%;margin-top:14px" });
    save.addEventListener("click", function () {
      var coords = null, lines = f.poly.value.split("\n").map(function (x) { return x.trim(); }).filter(Boolean);
      if (lines.length) {
        coords = lines.map(function (l) { var p = l.split(/[ ,]+/); return { lat: Number(p[0]), lng: Number(p[1]) }; });
        if (coords.some(function (p) { return !isFinite(p.lat) || !isFinite(p.lng); })) return msg(out, "Each boundary line must be: latitude, longitude.");
      }
      if (!f.name.value.trim()) return msg(out, "Enter a name.");
      save.disabled = true; msg(out, "");
      api(g ? "PUT" : "POST", "/admin/regions" + (g ? "/" + g.id : ""), { name: f.name.value.trim(), distance_unit: f.unit.value, timezone: f.tz.value.trim(), currency: f.cur.value, status: f.status.checked, coordinates: coords })
        .then(function (r) { save.disabled = false; if (r.ok) { toast("Saved"); pageRegions(root); } else msg(out, errText(r)); });
    });
    card.appendChild(save); root.appendChild(card);
  }

  // ---------- Ride options ----------
  function pageOptions(root) {
    loading(root);
    api("GET", "/admin/service-options").then(function (r) {
      var list = (r.body && r.body.data) || [];
      root.textContent = "";
      root.appendChild(head("Ride options", "Extras passengers can tick when booking, each with its own price."));
      if (can("service_option add")) {
        var n = text("", "e.g. Roof rack"), p = num("", "Price (₦)"), out = h("p", { class: "msg" });
        var add = h("button", { text: "Add option", style: "width:100%;margin-top:14px" });
        add.addEventListener("click", function () {
          if (!n.value.trim()) return msg(out, "Enter a name.");
          add.disabled = true;
          api("POST", "/admin/service-options", { name: n.value.trim(), price: nn(p) || 0 }).then(function (x) { add.disabled = false; if (x.ok) { toast("Added"); pageOptions(root); } else msg(out, errText(x)); });
        });
        root.appendChild(h("div", { class: "card" }, h("div", { class: "grid2" }, field("Name", n), field("Price (₦)", p)), out, add));
      }
      var card = h("div", { class: "card" });
      if (!list.length) card.appendChild(h("div", { class: "empty", text: "No options yet." }));
      list.forEach(function (o) {
        var price = num(o.price);
        var acts = h("div", { class: "acts" });
        if (can("service_option edit")) acts.appendChild(h("button", { class: "ghost small", text: "Save price", on: { click: function () {
          api("PUT", "/admin/service-options/" + o.id, { price: nn(price) || 0 }).then(function (x) { toast(x.ok ? "Saved" : errText(x), !x.ok); });
        } } }));
        if (can("service_option delete")) acts.appendChild(h("button", { class: "danger small", text: "Delete", on: { click: function () {
          confirmDo("Delete " + o.name + "?", function () { api("DELETE", "/admin/service-options/" + o.id).then(function (x) { toast(x.ok ? "Deleted" : errText(x), !x.ok); if (x.ok) pageOptions(root); }); });
        } } }));
        card.appendChild(h("div", { class: "item" },
          h("div", { class: "main" }, h("div", { class: "t", text: o.name }), h("div", { style: "max-width:200px;margin-top:6px" }, price), h("div", { style: "margin-top:8px" }, acts)),
          can("service_option edit") ? sw(o.status, function (on, input) {
            api("PUT", "/admin/service-options/" + o.id, { status: on }).then(function (x) { if (!x.ok) { input.checked = !on; toast(errText(x), true); } });
          }) : null));
      });
      root.appendChild(card);
    });
  }

  // ---------- Payment methods (unchanged behaviour, moved here) ----------
  var pm = { data: [], mode: {}, flash: null };
  function pagePayments(root) {
    loading(root);
    api("GET", "/admin/payment-gateways").then(function (r) {
      pm.data = (r.body && r.body.data) || [];
      root.textContent = "";
      var warn = h("p", { class: "msg err", text: "The server encryption key is not set yet, so credentials cannot be saved. Add the SETTINGS_ENCRYPTION_KEY secret in Cloudflare." });
      if (r.body && r.body.encryption_configured === false) warn.style.display = "block";
      root.appendChild(h("div", { class: "card" }, h("h2", { text: "Payment methods" }),
        h("p", { class: "muted", style: "margin:0", text: "Add each gateway's keys when its account is ready. Secret values are encrypted and never shown again after saving." }), warn));
      var list = h("div"); root.appendChild(list); renderPayments(list, root);
    });
  }
  function putGateway(type, body, out, done, fail) {
    msg(out, "");
    api("PUT", "/admin/payment-gateways/" + encodeURIComponent(type), body).then(function (r) {
      if (r.status === 200) { pm.flash = { type: type, text: "Saved." }; msg(out, "Saved.", true); done && done(); }
      else { msg(out, errText(r)); fail && fail(); }
    });
  }
  function renderPayments(list, root) {
    list.textContent = "";
    var canEdit = can("payment_gateway edit");
    pm.data.forEach(function (g) {
      var mode = pm.mode[g.type] || (g.is_test ? "test" : "live");
      var ready = g.ready_test || g.ready_live;
      var card = h("div", { class: "card" });
      card.appendChild(h("div", { class: "item", style: "border:0;padding:0" }, h("div", { class: "main t", text: g.title }),
        h("span", { class: "pill " + (g.status ? "on" : ""), text: g.status ? "On" : "Off" }),
        g.fields.length ? h("span", { class: "pill " + (ready ? "on" : "warn"), text: ready ? "Keys added" : "Needs keys" }) : null));
      var out = h("p", { class: "msg" });
      var reload = function () { pagePayments(root); };
      if (canEdit) {
        card.appendChild(h("div", { class: "row" }, h("div", { text: "Available to passengers" }),
          sw(g.status, function (on, input) { putGateway(g.type, { status: on }, out, reload, function () { input.checked = !on; }); })));
      }
      if (g.fields.length) {
        if (canEdit) {
          card.appendChild(h("div", { class: "row" }, h("div", {}, h("div", { text: "Live mode" }), h("div", { class: "hint", text: g.is_test ? "Currently using TEST keys (no real money)." : "Currently using LIVE keys (real money)." })),
            sw(!g.is_test, function (live, input) {
              if (live && !window.confirm("Switch " + g.title + " to LIVE? Real money will move.")) { input.checked = false; return; }
              putGateway(g.type, { is_test: !live }, out, reload, function () { input.checked = !live; });
            })));
          var tabs = h("div", { class: "tabs" });
          ["test", "live"].forEach(function (m) {
            tabs.appendChild(h("button", { type: "button", class: m === mode ? "active" : "", text: m === "test" ? "Test keys" : "Live keys", on: { click: function () { pm.mode[g.type] = m; renderPayments(list, root); } } }));
          });
          card.appendChild(tabs);
          var inputs = {};
          g.fields.forEach(function (f) {
            var cur = f[mode];
            card.appendChild(h("label", { class: "f", text: f.label }));
            var inp = h("input", { type: f.secret ? "password" : "text", autocomplete: "off", autocapitalize: "off", spellcheck: "false", placeholder: cur ? (f.secret ? cur.masked + "  (leave blank to keep)" : "") : "Not set" });
            if (cur && !f.secret) inp.value = cur.value || "";
            inputs[f.key] = inp; card.appendChild(inp);
            if (cur && f.secret) card.appendChild(h("div", { class: "set", text: "Saved " + cur.masked }));
            if (f.hint) card.appendChild(h("div", { class: "hint", text: f.hint }));
          });
          var save = h("button", { type: "button", text: "Save " + mode + " keys", style: "width:100%;margin-top:16px" });
          save.addEventListener("click", function () {
            var vals = {}; g.fields.forEach(function (f) { var v = inputs[f.key].value; if (v !== "") vals[f.key] = v; });
            if (!Object.keys(vals).length) return msg(out, "Nothing to save.");
            var creds = {}; creds[mode] = vals; save.disabled = true;
            putGateway(g.type, { credentials: creds }, out, reload, function () { save.disabled = false; });
          });
          card.appendChild(save);
        }
      } else card.appendChild(h("p", { class: "muted", text: "No keys needed." }));
      card.appendChild(out);
      if (pm.flash && pm.flash.type === g.type) { msg(out, pm.flash.text, true); pm.flash = null; }
      list.appendChild(card);
    });
    if (!pm.data.length) list.appendChild(h("div", { class: "empty", text: "No payment methods yet." }));
  }

  // ---------- Maps (Google / OpenStreetMap switch) ----------
  function pageMaps(root) {
    loading(root);
    api("GET", "/admin/map-settings").then(function (r) {
      var d = (r.body || {}).data;
      if (!r.ok || !d) { root.textContent = ""; root.appendChild(head("Maps", "")); root.appendChild(h("p", { class: "msg", text: errText(r) })); return; }
      root.textContent = "";
      root.appendChild(head("Maps", "Choose which map service the apps and fare routing use. Google Maps stays available; OpenStreetMap needs no Google account."));

      var status = h("div", { class: "card" });
      status.appendChild(h("div", { class: "t", text: "Right now the apps use: " + (d.active === "google" ? "Google Maps" : "OpenStreetMap") }));
      status.appendChild(h("p", { class: "muted", text: "Google server key: " + (d.google_server_key_set ? "set" : "not set") + (d.google_failed_recently ? " \u00B7 Google did not answer recently (" + d.google_failed_at + ")" : "") }));
      root.appendChild(status);

      var provider = select([["auto", "Automatic (Google when it works, otherwise OpenStreetMap)"], ["google", "Always Google Maps"], ["osm", "Always OpenStreetMap"]], d.provider);
      var tiles = text(d.osm_tile_url, "https://tile.openstreetmap.org/{z}/{x}/{y}.png");
      var routing = text(d.osm_routing_url, "https://router.project-osrm.org");
      var out = h("p", { class: "msg" });
      var card = h("div", { class: "card" },
        field("Map service", provider, "Automatic switches to OpenStreetMap by itself when Google is not set up or stops answering. Pick one to force it."),
        field("OpenStreetMap tile address", tiles, "Where map pictures come from. The free openstreetmap.org tiles are for light use only; for real traffic use a provider such as MapTiler or Stadia and paste its address here."),
        field("OpenStreetMap route service", routing, "Used for road distance and time. The free public OSRM server is for light use; paste your own or a provider address for real traffic."));
      if (can("map_settings edit")) {
        var save = h("button", { text: "Save", class: "small", style: "margin-top:10px" });
        save.addEventListener("click", function () {
          save.disabled = true;
          api("PUT", "/admin/map-settings", { provider: provider.value, osm_tile_url: tiles.value.trim(), osm_routing_url: routing.value.trim() }).then(function (x) {
            save.disabled = false;
            if (x.ok) { toast("Saved"); pageMaps(root); } else msg(out, errText(x));
          });
        });
        card.appendChild(save);
      }
      card.appendChild(out);
      root.appendChild(card);
    });
  }

  // ---------- Wallet transfers (passenger to passenger) ----------
  var tr = { page: 1 };
  function pageTransfers(root) {
    loading(root);
    api("GET", "/admin/wallet-transfers?page=" + tr.page).then(function (r) {
      var b = r.body || {}, s = b.settings || {}, list = b.data || [], pg = b.pagination || { page: 1, total_pages: 1, total: 0 };
      root.textContent = "";
      root.appendChild(head("Wallet transfers", "Passengers can send trip money to another passenger's wallet with their username and 4-digit PIN. Money moves at once; these limits keep it safe."));
      var enabled = select([["1", "On"], ["0", "Off"]], s.enabled === false ? "0" : "1");
      var min = num(s.min), max = num(s.max), daily = num(s.daily_limit), out = h("p", { class: "msg" });
      var card = h("div", { class: "card" }, field("Transfers", enabled), field("Smallest transfer (\u20A6)", min), field("Largest single transfer (\u20A6)", max), field("Daily limit per passenger (\u20A6)", daily));
      if (can("wallet_transfer edit")) {
        var save = h("button", { text: "Save", class: "small", style: "margin-top:10px" });
        save.addEventListener("click", function () {
          save.disabled = true;
          api("PUT", "/admin/wallet-transfers/settings", { enabled: enabled.value === "1", min: nn(min), max: nn(max), daily_limit: nn(daily) }).then(function (x) { save.disabled = false; if (x.ok) { toast("Saved"); pageTransfers(root); } else msg(out, errText(x)); });
        });
        card.appendChild(save);
      }
      card.appendChild(out); root.appendChild(card);
      var hist = h("div", { class: "card" }, h("div", { class: "t", text: pg.total + " transfer" + (pg.total === 1 ? "" : "s") }));
      if (!list.length) hist.appendChild(h("div", { class: "empty", text: "No transfers yet." }));
      list.forEach(function (t) {
        hist.appendChild(h("div", { class: "row", style: "padding:8px 0;border-top:1px solid var(--line,#eee)" },
          h("div", { class: "t", text: "\u20A6" + Number(t.amount).toLocaleString() + " \u00B7 @" + t.sender + " \u2192 @" + t.recipient }),
          h("div", { class: "s", text: String(t.created_at).slice(0, 16).replace("T", " ") + (t.note ? " \u00B7 " + t.note : "") })));
      });
      root.appendChild(hist);
    });
  }

  // ---------- PayMyRide (someone else pays a passenger's fare) ----------
  var CURRENCY_OPTIONS = [["NGN", "Nigerian naira (NGN)"], ["GHS", "Ghanaian cedi (GHS)"], ["XOF", "West African CFA franc (XOF)"], ["XAF", "Central African CFA franc (XAF)"], ["GMD", "Gambian dalasi (GMD)"], ["GNF", "Guinean franc (GNF)"], ["LRD", "Liberian dollar (LRD)"], ["SLE", "Sierra Leonean leone (SLE)"], ["MRU", "Mauritanian ouguiya (MRU)"], ["CVE", "Cape Verdean escudo (CVE)"], ["KES", "Kenyan shilling (KES)"], ["ZAR", "South African rand (ZAR)"], ["USD", "US dollar (USD)"], ["GBP", "British pound (GBP)"], ["EUR", "Euro (EUR)"]];
  var pmr = { page: 1 };
  function pagePayMyRide(root) {
    loading(root);
    api("GET", "/admin/paymyride?page=" + pmr.page).then(function (r) {
      var b = r.body || {}, s = b.settings || {}, list = b.data || [], pg = b.pagination || { page: 1, total_pages: 1, total: 0 };
      root.textContent = "";
      root.appendChild(head("PayMyRide", "A passenger can share a link so a friend, family member or employer pays the ride fare through Korapay or bank transfer. The money lands in the passenger's wallet and the ride is paid from it."));
      var enabled = select([["1", "On"], ["0", "Off"]], s.enabled === false ? "0" : "1");
      var hours = num(s.link_hours), out = h("p", { class: "msg" });
      var card = h("div", { class: "card" }, field("PayMyRide", enabled), field("Link stays valid for (hours)", hours));
      if (can("paymyride edit")) {
        var save = h("button", { text: "Save", class: "small", style: "margin-top:10px" });
        save.addEventListener("click", function () {
          save.disabled = true;
          api("PUT", "/admin/paymyride/settings", { enabled: enabled.value === "1", link_hours: nn(hours) }).then(function (x) { save.disabled = false; if (x.ok) { toast("Saved"); pagePayMyRide(root); } else msg(out, errText(x)); });
        });
        card.appendChild(save);
      }
      card.appendChild(out); root.appendChild(card);
      var hist = h("div", { class: "card" }, h("div", { class: "t", text: pg.total + " link" + (pg.total === 1 ? "" : "s") }));
      if (!list.length) hist.appendChild(h("div", { class: "empty", text: "No pay links yet." }));
      list.forEach(function (t) {
        hist.appendChild(h("div", { class: "row", style: "padding:8px 0;border-top:1px solid var(--line,#eee)" },
          h("div", { class: "t", text: "\u20A6" + Number(t.amount).toLocaleString() + " \u00B7 @" + t.passenger + " \u00B7 " + t.status }),
          h("div", { class: "s", text: String(t.created_at).slice(0, 16).replace("T", " ") + (t.payer_name ? " \u00B7 paid by " + t.payer_name : "") + (t.gateway ? " via " + t.gateway : "") })));
      });
      root.appendChild(hist);
    });
  }

  // ---------- User accounts (support: temporary password) ----------
  function pageUserAccounts(root) {
    root.textContent = "";
    root.appendChild(head("User accounts", "Find a rider or driver who cannot reset their password by email, and give them a temporary password. Tell them to change it after logging in. All their devices are signed out."));
    var q = text("", "Name, username, phone or email"), out = h("div");
    var go = h("button", { text: "Search", class: "small", style: "margin-top:10px" });
    function search() {
      var term = q.value.trim();
      if (term.length < 2) { toast("Type at least 2 characters", true); return; }
      go.disabled = true;
      api("GET", "/admin/users?q=" + encodeURIComponent(term)).then(function (r) {
        go.disabled = false; out.textContent = "";
        var list = (r.body || {}).data || [];
        if (!r.ok) { out.appendChild(h("p", { class: "msg err", text: errText(r) })); return; }
        if (!list.length) out.appendChild(h("div", { class: "empty", text: "No matching rider or driver." }));
        list.forEach(function (u) {
          var row = h("div", { class: "row", style: "display:flex;align-items:center;gap:10px;padding:8px 0;border-top:1px solid var(--line,#eee)" });
          row.appendChild(h("div", { style: "flex:1" }, h("div", { class: "t", text: (u.display_name || u.username) + " \u00B7 " + u.user_type }),
            h("div", { class: "s", text: [u.username ? "@" + u.username : "", u.contact_number ? (u.country_code || "") + u.contact_number : "", u.email || "no email", u.status].filter(Boolean).join(" \u00B7 ") })));
          if (can("user_account edit")) {
            var b = h("button", { text: "Set temporary password", class: "small secondary" });
            b.addEventListener("click", function () {
              if (!window.confirm("Set a new temporary password for " + (u.display_name || u.username) + "? Their current password stops working and they are signed out.")) return;
              b.disabled = true;
              api("POST", "/admin/users/" + u.id + "/reset-password").then(function (x) {
                b.disabled = false;
                if (!x.ok) { toast(errText(x), true); return; }
                window.prompt("Temporary password for " + (x.body.name || "this user") + " (shown once). Copy it and send it to them privately:", x.body.temporary_password);
              });
            });
            row.appendChild(b);
          }
          out.appendChild(row);
        });
      });
    }
    go.addEventListener("click", search);
    q.addEventListener("keydown", function (e) { if (e.key === "Enter") search(); });
    root.appendChild(h("div", { class: "card" }, field("Find a user", q), go));
    root.appendChild(h("div", { class: "card" }, out));
  }

  // ---------- Driver document types and rules ----------
  var pd = { edit: null };
  function pageDocuments(root) {
    loading(root);
    api("GET", "/admin/documents").then(function (r) {
      var b = r.body || {}, docs = b.data || [], services = b.services || [], rules = b.rules || {};
      root.textContent = "";
      root.appendChild(head("Document types", "The papers a driver must upload before approval (licence, vehicle papers, insurance...). A document can apply to every ride type or only to chosen ones."));

      // Age and licence rules
      var age = num(rules.min_age), yrs = num(rules.min_licence_years), rout = h("p", { class: "msg" });
      var rc = h("div", { class: "card" }, h("div", { class: "t", text: "Driver rules" }), field("Minimum age", age), field("Minimum years holding a licence", yrs));
      if (can("document edit")) {
        var rs = h("button", { text: "Save rules", class: "small", style: "margin-top:10px" });
        rs.addEventListener("click", function () {
          rs.disabled = true;
          api("PUT", "/admin/driver-rules", { min_age: nn(age), min_licence_years: nn(yrs) }).then(function (x) { rs.disabled = false; if (x.ok) toast("Saved"); else msg(rout, errText(x)); });
        });
        rc.appendChild(rs);
      }
      rc.appendChild(rout); root.appendChild(rc);

      // Add / edit form
      if (can("document edit")) {
        var e = pd.edit;
        var name = text(e ? e.name : "", "e.g. Driver's licence");
        var req = h("input", { type: "checkbox" }); req.checked = e ? e.is_required : true;
        var exp = h("input", { type: "checkbox" }); exp.checked = e ? e.has_expiry_date : false;
        var act = h("input", { type: "checkbox" }); act.checked = e ? e.status : true;
        var boxes = services.map(function (s) {
          var cb = h("input", { type: "checkbox" }); cb.checked = !!(e && e.service_ids.indexOf(s.id) >= 0);
          return { id: s.id, cb: cb, el: h("label", { style: "display:flex;gap:6px;align-items:center;margin:4px 0" }, cb, h("span", { text: s.name })) };
        });
        var fout = h("p", { class: "msg" });
        var save = h("button", { text: e ? "Save changes" : "Add document type", class: "small", style: "margin-top:10px" });
        save.addEventListener("click", function () {
          save.disabled = true;
          var body = { name: name.value, is_required: req.checked, has_expiry_date: exp.checked, status: act.checked, service_ids: boxes.filter(function (x) { return x.cb.checked; }).map(function (x) { return x.id; }) };
          api(e ? "PUT" : "POST", "/admin/documents" + (e ? "/" + e.id : ""), body).then(function (x) { save.disabled = false; if (x.ok) { toast("Saved"); pd.edit = null; pageDocuments(root); } else msg(fout, errText(x)); });
        });
        var fc = h("div", { class: "card" }, h("div", { class: "t", text: e ? "Edit " + e.name : "Add a document type" }), field("Name", name),
          h("label", { style: "display:flex;gap:6px;align-items:center;margin:8px 0" }, req, h("span", { text: "Required before approval" })),
          h("label", { style: "display:flex;gap:6px;align-items:center;margin:8px 0" }, exp, h("span", { text: "Has an expiry date (driver enters it)" })),
          h("label", { style: "display:flex;gap:6px;align-items:center;margin:8px 0" }, act, h("span", { text: "Active (shown to applicants)" })),
          h("div", { class: "s", text: "Applies to these ride types (tick none = every ride type):" }));
        boxes.forEach(function (x) { fc.appendChild(x.el); });
        fc.appendChild(save);
        if (e) { var cancel = h("button", { text: "Cancel", class: "small secondary", style: "margin:10px 0 0 8px" }); cancel.addEventListener("click", function () { pd.edit = null; pageDocuments(root); }); fc.appendChild(cancel); }
        fc.appendChild(fout); root.appendChild(fc);
      }

      // List
      var lc = h("div", { class: "card" }, h("div", { class: "t", text: docs.length + " document type" + (docs.length === 1 ? "" : "s") }));
      if (!docs.length) lc.appendChild(h("div", { class: "empty", text: "None yet. Until you add some, drivers are not asked for any documents." }));
      docs.forEach(function (d) {
        var names = d.service_ids.length ? d.service_ids.map(function (id) { var s = services.filter(function (x) { return x.id === id; })[0]; return s ? s.name : "#" + id; }).join(", ") : "all ride types";
        var row = h("div", { class: "row", style: "display:flex;align-items:center;gap:10px;padding:8px 0;border-top:1px solid var(--line,#eee)" },
          h("div", { style: "flex:1" }, h("div", { class: "t", text: d.name + (d.status ? "" : " (off)") }),
            h("div", { class: "s", text: (d.is_required ? "Required" : "Optional") + (d.has_expiry_date ? " \u00B7 has expiry" : "") + " \u00B7 " + names + " \u00B7 " + d.uploads + " upload" + (d.uploads === 1 ? "" : "s") })));
        if (can("document edit")) {
          var eb = h("button", { text: "Edit", class: "small secondary" }); eb.addEventListener("click", function () { pd.edit = d; pageDocuments(root); window.scrollTo(0, 0); });
          var db2 = h("button", { text: "Delete", class: "small secondary" });
          db2.addEventListener("click", function () {
            if (!window.confirm("Delete " + d.name + "?")) return;
            api("DELETE", "/admin/documents/" + d.id).then(function (x) { if (x.ok) { toast(x.body.message || "Deleted"); pageDocuments(root); } else toast(errText(x), true); });
          });
          row.appendChild(eb); row.appendChild(db2);
        }
        lc.appendChild(row);
      });
      root.appendChild(lc);
    });
  }

  // ---------- Banks (driver payout accounts) ----------
  var KIND_LABEL = { bank: "Bank", mfb: "Microfinance bank", mmo: "Mobile money / wallet" };
  function pageBanks(root) {
    loading(root);
    api("GET", "/admin/banks").then(function (r) {
      var list = (r.body || {}).data || [];
      root.textContent = "";
      root.appendChild(head("Banks", "Nigerian banks, microfinance banks and mobile money operators drivers can choose for payouts. Account names are checked through Korapay once its keys are saved under Payment methods."));
      var out = h("p", { class: "msg" });
      if (can("bank edit")) {
        var name = text("", "Bank name"), code = text("", "Bank code, e.g. 058"), kind = select([["bank", "Bank"], ["mfb", "Microfinance bank"], ["mmo", "Mobile money / wallet"]], "bank");
        var add = h("button", { text: "Add bank", class: "small", style: "margin-top:10px" });
        add.addEventListener("click", function () {
          add.disabled = true;
          api("POST", "/admin/banks", { name: name.value, code: code.value, kind: kind.value }).then(function (x) { add.disabled = false; if (x.ok) { toast("Bank added"); pageBanks(root); } else msg(out, errText(x)); });
        });
        var sync = h("button", { text: "Fetch logos from public list", class: "small secondary", style: "margin:10px 0 0 8px" });
        sync.addEventListener("click", function () {
          sync.disabled = true;
          api("POST", "/admin/banks/sync-logos").then(function (x) { sync.disabled = false; toast(x.ok ? x.body.message : errText(x), !x.ok); if (x.ok) pageBanks(root); });
        });
        root.appendChild(h("div", { class: "card" }, h("div", { class: "t", text: "Add a bank" }), field("Name", name), field("Code", code, "Use the code Korapay expects for this bank."), field("Type", kind), add, sync, out));
      }
      var card = h("div", { class: "card" }, h("div", { class: "t", text: list.length + " banks" }));
      list.forEach(function (b) {
        var row = h("div", { class: "row", style: "display:flex;align-items:center;gap:10px;padding:8px 0;border-top:1px solid var(--line,#eee)" });
        row.appendChild(b.logo_url ? h("img", { src: b.logo_url, alt: "", style: "width:28px;height:28px;border-radius:6px;object-fit:contain" }) : h("div", { style: "width:28px;height:28px;border-radius:6px;background:#f3e3dc;display:flex;align-items:center;justify-content:center;font-weight:700", text: b.name.charAt(0) }));
        row.appendChild(h("div", { style: "flex:1" }, h("div", { class: "t", text: b.name }), h("div", { class: "s", text: b.code + " \u00B7 " + (KIND_LABEL[b.kind] || b.kind) + (b.active ? "" : " \u00B7 hidden") })));
        if (can("bank edit")) {
          var tog = h("button", { text: b.active ? "Hide" : "Show", class: "small secondary" });
          tog.addEventListener("click", function () { api("PUT", "/admin/banks/" + b.id, { active: !b.active }).then(function (x) { if (x.ok) pageBanks(root); else toast(errText(x), true); }); });
          var ed = h("button", { text: "Edit", class: "small secondary" });
          ed.addEventListener("click", function () {
            var n = window.prompt("Bank name", b.name); if (n === null) return;
            var c2 = window.prompt("Bank code", b.code); if (c2 === null) return;
            var l = window.prompt("Logo image address (leave empty for none)", b.logo_url || ""); if (l === null) return;
            api("PUT", "/admin/banks/" + b.id, { name: n, code: c2, logo_url: l }).then(function (x) { if (x.ok) { toast("Saved"); pageBanks(root); } else toast(errText(x), true); });
          });
          row.appendChild(tog); row.appendChild(ed);
        }
        card.appendChild(row);
      });
      root.appendChild(card);
    });
  }

  // ---------- Driver wallets (commission) ----------
  var dw = { filter: "blocked", q: "", page: 1 };
  function pageDriverWallets(root) {
    loading(root);
    var qs = "?filter=" + dw.filter + "&page=" + dw.page + (dw.q ? "&q=" + encodeURIComponent(dw.q) : "");
    api("GET", "/admin/driver-wallets" + qs).then(function (r) {
      var b = r.body || {}, list = b.data || [], pg = b.pagination || { page: 1, total_pages: 1, total: 0 };
      root.textContent = "";
      root.appendChild(head("Driver wallets", "Cash trips take DROP's commission from the driver's wallet. Below the minimum, a driver cannot take new trips."));

      var min = num(b.minimum), out = h("p", { class: "msg" });
      var card = h("div", { class: "card" }, field("Minimum balance to take trips (₦)", min, "0 means a driver whose balance is negative is blocked. A ride type can set its own minimum."));
      if (can("driver_wallet edit")) {
        var save = h("button", { text: "Save minimum", class: "small", style: "margin-top:10px" });
        save.addEventListener("click", function () {
          save.disabled = true;
          api("PUT", "/admin/wallet-settings", { driver_min_wallet_balance: nn(min) === null ? 0 : nn(min) }).then(function (x) {
            save.disabled = false; if (x.ok) { toast("Saved"); pageDriverWallets(root); } else msg(out, errText(x));
          });
        });
        card.appendChild(save);
      }
      card.appendChild(out); root.appendChild(card);

      var tabs = h("div", { class: "tabs", style: "margin-bottom:12px" });
      [["blocked", "Blocked"], ["all", "All drivers"]].forEach(function (t) {
        tabs.appendChild(h("button", { type: "button", class: dw.filter === t[0] ? "active" : "", text: t[1], on: { click: function () { dw.filter = t[0]; dw.page = 1; pageDriverWallets(root); } } }));
      });
      root.appendChild(tabs);
      var search = h("input", { type: "search", value: dw.q, placeholder: "Search name, email or phone" });
      search.addEventListener("keydown", function (e) { if (e.key === "Enter") { dw.q = search.value.trim(); dw.page = 1; pageDriverWallets(root); } });
      root.appendChild(h("div", { class: "card" }, search));

      var box = h("div", { class: "card" });
      if (!list.length) box.appendChild(h("div", { class: "empty", text: dw.filter === "blocked" ? "No blocked drivers." : "No drivers found." }));
      list.forEach(function (d) {
        var acts = h("div", { class: "acts" });
        acts.appendChild(h("button", { class: "ghost small", text: "History", on: { click: function () { driverHistory(root, d); } } }));
        if (can("driver_wallet edit")) acts.appendChild(h("button", { class: "ghost small", text: "Adjust", on: { click: function () { driverAdjust(root, d); } } }));
        box.appendChild(h("div", { class: "item" },
          h("div", { class: "main" }, h("div", { class: "t", text: ((d.first_name || "") + " " + (d.last_name || "")).trim() || d.email }),
            h("div", { class: "s", text: [d.email, d.contact_number].filter(Boolean).join(" · ") }),
            h("div", { class: "s", text: "Balance " + naira(d.balance) }), h("div", { style: "margin-top:8px" }, acts)),
          h("span", { class: "pill " + (d.blocked ? "warn" : "on"), text: d.blocked ? "Blocked" : "OK" })));
      });
      if (pg.total_pages > 1) {
        box.appendChild(h("div", { class: "row" },
          h("button", { class: "ghost small", text: "Previous", disabled: pg.page <= 1, on: { click: function () { dw.page--; pageDriverWallets(root); } } }),
          h("span", { class: "muted", text: "Page " + pg.page + " of " + pg.total_pages }),
          h("button", { class: "ghost small", text: "Next", disabled: pg.page >= pg.total_pages, on: { click: function () { dw.page++; pageDriverWallets(root); } } })));
      }
      root.appendChild(box);
    });
  }
  function driverHistory(root, d) {
    loading(root);
    api("GET", "/admin/driver-wallets/" + d.id + "/ledger").then(function (r) {
      var rows = (r.body && r.body.data) || [];
      root.textContent = "";
      root.appendChild(head("Wallet history", ((d.first_name || "") + " " + (d.last_name || "")).trim(), h("button", { class: "ghost", text: "Back", on: { click: function () { pageDriverWallets(root); } } })));
      var card = h("div", { class: "card" });
      if (!rows.length) card.appendChild(h("div", { class: "empty", text: "No transactions yet." }));
      rows.forEach(function (x) {
        card.appendChild(h("div", { class: "item" },
          h("div", { class: "main" }, h("div", { class: "t", text: (x.direction === "credit" ? "+ " : "- ") + naira(x.amount) + "  · " + x.kind.replace(/_/g, " ") }),
            h("div", { class: "s", text: new Date(x.created_at).toLocaleString() + (x.description ? " · " + x.description : "") })),
          h("span", { class: "pill", text: "Bal " + naira(x.balance_after) })));
      });
      root.appendChild(card);
    });
  }
  function driverAdjust(root, d) {
    var dir = select([["credit", "Add money (credit)"], ["debit", "Take money (debit)"]], "credit"), amt = num("", "Amount (₦)"), why = text("", "Reason (required)"), out = h("p", { class: "msg" });
    root.textContent = "";
    root.appendChild(head("Adjust wallet", ((d.first_name || "") + " " + (d.last_name || "")).trim() + " · balance " + naira(d.balance), h("button", { class: "ghost", text: "Back", on: { click: function () { pageDriverWallets(root); } } })));
    var go = h("button", { text: "Apply", style: "width:100%;margin-top:14px" });
    go.addEventListener("click", function () {
      var a = nn(amt); if (!a || a <= 0) return msg(out, "Enter an amount."); if (why.value.trim().length < 3) return msg(out, "Give a short reason.");
      if (!window.confirm((dir.value === "credit" ? "Add " : "Take ") + naira(a) + (dir.value === "credit" ? " to " : " from ") + "this driver's wallet?")) return;
      go.disabled = true;
      api("POST", "/admin/driver-wallets/" + d.id + "/adjust", { direction: dir.value, amount: a, reason: why.value.trim() }).then(function (x) {
        go.disabled = false; if (x.ok) { toast("Done. New balance " + naira(x.body.balance)); pageDriverWallets(root); } else msg(out, errText(x));
      });
    });
    root.appendChild(h("div", { class: "card" }, field("Type", dir), field("Amount (₦)", amt), field("Reason", why, "Saved in the wallet history and the audit log."), out, go));
  }

  // ---------- Driver applications ----------
  var da = { status: "queue", page: 1, q: "" };
  var APP_STATUS = { draft: "Draft", submitted: "Submitted", in_review: "In review", needs_changes: "Needs changes", approved: "Approved", rejected: "Rejected", suspended: "Suspended" };
  var DOC_STATUS = { missing: "Missing", pending: "To review", approved: "Approved", rejected: "Rejected" };
  function pillFor(st) { return st === "approved" ? "on" : st === "rejected" || st === "suspended" || st === "needs_changes" || st === "missing" ? "warn" : ""; }
  function fullName(d) { return ((d.first_name || "") + " " + (d.last_name || "")).trim() || d.email || ""; }
  /** Fetches a private file with the admin's token and returns a temporary blob URL. */
  function fileUrl(path) {
    return fetch("/api" + path, { headers: { Authorization: "Bearer " + TOKEN } }).then(function (r) {
      if (!r.ok) throw new Error("not found");
      return r.blob();
    }).then(function (b) { return { url: URL.createObjectURL(b), type: b.type }; });
  }

  function pageDriverApplications(root) {
    loading(root);
    var qs = "?status=" + da.status + "&page=" + da.page + (da.q ? "&q=" + encodeURIComponent(da.q) : "");
    api("GET", "/admin/driver-applications" + qs).then(function (r) {
      var b = r.body || {}, list = b.data || [], counts = b.counts || {}, pg = b.pagination || { page: 1, total_pages: 1 };
      root.textContent = "";
      root.appendChild(head("Driver applications", "Review documents, then approve, ask for changes or reject."));
      var queueN = (counts.submitted || 0) + (counts.in_review || 0);
      var tabs = h("div", { class: "tabs wrap", style: "margin-bottom:12px" });
      [["queue", "To review" + (queueN ? " (" + queueN + ")" : "")], ["needs_changes", "Needs changes"], ["approved", "Approved"], ["rejected", "Rejected"], ["suspended", "Suspended"], ["all", "All"]].forEach(function (t) {
        tabs.appendChild(h("button", { type: "button", class: da.status === t[0] ? "active" : "", text: t[1], on: { click: function () { da.status = t[0]; da.page = 1; pageDriverApplications(root); } } }));
      });
      root.appendChild(tabs);
      var search = h("input", { type: "search", value: da.q, placeholder: "Search name, email, phone or plate" });
      search.addEventListener("keydown", function (e) { if (e.key === "Enter") { da.q = search.value.trim(); da.page = 1; pageDriverApplications(root); } });
      root.appendChild(h("div", { class: "card" }, search));
      var box = h("div", { class: "card" });
      if (!list.length) box.appendChild(h("div", { class: "empty", text: da.status === "queue" ? "Nothing waiting for review." : "No applications here." }));
      list.forEach(function (a) {
        var vehicle = [a.vehicle_make, a.vehicle_model, a.vehicle_plate].filter(Boolean).join(" · ");
        box.appendChild(h("div", { class: "item" },
          h("div", { class: "main" }, h("div", { class: "t", text: fullName(a) }),
            h("div", { class: "s", text: [a.ride_type, vehicle].filter(Boolean).join(" · ") || "No vehicle yet" }),
            h("div", { class: "s", text: [a.email, a.contact_number].filter(Boolean).join(" · ") }),
            h("div", { class: "s", text: a.submitted_at ? "Submitted " + new Date(a.submitted_at).toLocaleString() : "Not submitted" }),
            h("div", { style: "margin-top:8px" }, h("button", { class: "ghost small", text: "Open", on: { click: function () { applicationDetail(root, a.id); } } }))),
          h("span", { class: "pill " + pillFor(a.status), text: APP_STATUS[a.status] || a.status })));
      });
      if (pg.total_pages > 1) {
        box.appendChild(h("div", { class: "row" },
          h("button", { class: "ghost small", text: "Previous", disabled: pg.page <= 1, on: { click: function () { da.page--; pageDriverApplications(root); } } }),
          h("span", { class: "muted", text: "Page " + pg.page + " of " + pg.total_pages }),
          h("button", { class: "ghost small", text: "Next", disabled: pg.page >= pg.total_pages, on: { click: function () { da.page++; pageDriverApplications(root); } } })));
      }
      root.appendChild(box);
    });
  }

  function applicationDetail(root, id) {
    loading(root);
    api("GET", "/admin/driver-applications/" + id).then(function (r) {
      root.textContent = "";
      var back = h("button", { class: "ghost", text: "Back", on: { click: function () { pageDriverApplications(root); } } });
      if (!r.ok) { root.appendChild(head("Application", null, back)); root.appendChild(h("div", { class: "card" }, h("div", { class: "empty", text: errText(r) }))); return; }
      var d = r.body.data;
      root.appendChild(head(fullName(d), [d.email, d.contact_number].filter(Boolean).join(" · "), back));

      var info = h("div", { class: "card" },
        h("div", { class: "bar" }, h("h3", { text: "Application" }), h("span", { class: "pill " + pillFor(d.status), text: APP_STATUS[d.status] || d.status })));
      var rows = [
        ["Ride type", d.ride_type], ["Date of birth", d.date_of_birth ? String(d.date_of_birth).slice(0, 10) : null], ["Years driving", d.licence_years],
        ["Vehicle", [d.vehicle_make, d.vehicle_model, d.vehicle_year, d.vehicle_colour].filter(Boolean).join(" ")], ["Plate", d.vehicle_plate], ["Seats", d.vehicle_seats],
        ["Submitted", d.submitted_at ? new Date(d.submitted_at).toLocaleString() : null], ["Last decision", d.reviewed_at ? new Date(d.reviewed_at).toLocaleString() : null], ["Note to driver", d.review_note]
      ];
      rows.forEach(function (x) { if (x[1] !== null && x[1] !== undefined && x[1] !== "") info.appendChild(h("div", { class: "kv" }, h("span", { class: "k", text: x[0] }), h("span", { text: String(x[1]) }))); });
      if (d.has_photo) {
        var holder = h("div", { class: "s", text: "Loading photo…" });
        info.appendChild(holder);
        fileUrl("/admin/driver-applications/" + id + "/photo").then(function (f) { holder.textContent = ""; holder.appendChild(h("img", { class: "docimg", src: f.url, alt: "Applicant photo" })); }).catch(function () { holder.textContent = "Photo could not be loaded."; });
      } else info.appendChild(h("div", { class: "s", text: "No photo uploaded." }));
      root.appendChild(info);

      var canEdit = can("driver_application edit"), reviewable = d.status === "submitted" || d.status === "in_review";
      var docs = h("div", { class: "card" }, h("h3", { text: "Documents" }));
      if (!d.documents.length) docs.appendChild(h("div", { class: "empty", text: "No documents are required for this ride type." }));
      d.documents.forEach(function (x) {
        var view = h("div");
        var acts = h("div", { class: "acts" });
        if (x.uploaded) acts.appendChild(h("button", { class: "ghost small", text: "View", on: { click: function (e) {
          var btn = e.target; btn.disabled = true; btn.textContent = "Loading…";
          fileUrl("/admin/driver-applications/" + id + "/documents/" + x.document_id + "/file").then(function (f) {
            btn.remove();
            if (f.type === "application/pdf") view.appendChild(h("a", { href: f.url, target: "_blank", rel: "noopener", text: "Open the PDF" }));
            else view.appendChild(h("img", { class: "docimg", src: f.url, alt: x.name }));
          }).catch(function () { btn.disabled = false; btn.textContent = "View"; toast("Could not open the file", true); });
        } } }));
        if (x.uploaded && canEdit && reviewable) {
          if (x.status !== "approved") acts.appendChild(h("button", { class: "small", text: "Approve", on: { click: function () {
            api("PUT", "/admin/driver-applications/" + id + "/documents/" + x.document_id, { status: "approved" }).then(function (z) { toast(z.ok ? "Approved" : errText(z), !z.ok); if (z.ok) applicationDetail(root, id); });
          } } }));
          if (x.status !== "rejected") acts.appendChild(h("button", { class: "danger small", text: "Reject", on: { click: function () {
            var note = window.prompt("What is wrong with this document? The driver will see this."); if (!note || !note.trim()) return;
            api("PUT", "/admin/driver-applications/" + id + "/documents/" + x.document_id, { status: "rejected", note: note.trim() }).then(function (z) { toast(z.ok ? "Rejected" : errText(z), !z.ok); if (z.ok) applicationDetail(root, id); });
          } } }));
        }
        docs.appendChild(h("div", { class: "item" },
          h("div", { class: "main" }, h("div", { class: "t", text: x.name + (x.required ? "" : " (optional)") }),
            h("div", { class: "s", text: (x.has_expiry_date && x.expire_date ? "Expires " + x.expire_date + " · " : "") + (x.uploaded_at ? "Uploaded " + new Date(x.uploaded_at).toLocaleString() : "Not uploaded") }),
            x.note ? h("div", { class: "s", text: "Note: " + x.note }) : null,
            h("div", { style: "margin-top:8px" }, acts), view),
          h("span", { class: "pill " + pillFor(x.status), text: DOC_STATUS[x.status] || x.status })));
      });
      root.appendChild(docs);

      var actions = [];
      if (d.status === "submitted") actions.push(["start_review", "Start review", "ghost", false]);
      if (reviewable) { actions.push(["approve", "Approve driver", "", false], ["needs_changes", "Ask for changes", "ghost", true], ["reject", "Reject", "danger", true]); }
      if (d.status === "approved") actions.push(["suspend", "Suspend driver", "danger", true]);
      if (d.status === "suspended") actions.push(["reinstate", "Reinstate driver", "", false]);
      if (canEdit && actions.length) {
        var note = h("textarea", { rows: "3", placeholder: "Reason (shown to the driver; required to reject, ask for changes or suspend)" });
        var out = h("p", { class: "msg" }), bar = h("div", { class: "acts", style: "margin-top:12px" });
        actions.forEach(function (a) {
          bar.appendChild(h("button", { class: a[2] + " small", text: a[1], on: { click: function (e) {
            if (a[3] && note.value.trim().length < 3) return msg(out, "Write a short reason first.");
            if (!window.confirm(a[1] + " for " + fullName(d) + "?")) return;
            e.target.disabled = true;
            api("POST", "/admin/driver-applications/" + id + "/review", { action: a[0], note: note.value.trim() || undefined }).then(function (z) {
              if (z.ok) { toast("Done: " + (APP_STATUS[z.body.status] || z.body.status)); applicationDetail(root, id); }
              else { e.target.disabled = false; msg(out, errText(z) + (z.body && z.body.missing ? " Still to approve: " + z.body.missing.map(function (m) { return m.name; }).join(", ") + "." : "")); }
            });
          } } }));
        });
        root.appendChild(h("div", { class: "card" }, h("h3", { text: "Decision" }), note, out, bar));
      }
    });
  }

  // ---------- Roles ----------
  function pageRoles(root) {
    loading(root);
    Promise.all([api("GET", "/admin/roles"), api("GET", "/admin/permissions")]).then(function (res) {
      var roles = (res[0].body && res[0].body.data) || [], mods = (res[1].body && res[1].body.data) || [];
      root.textContent = "";
      root.appendChild(head("Roles", "Decide exactly what each kind of admin can do.", can("role add") ? h("button", { text: "Add role", on: { click: function () { roleForm(root, null, mods); } } }) : null));
      var card = h("div", { class: "card" });
      roles.forEach(function (r) {
        var acts = h("div", { class: "acts" });
        if (!r.is_super && can("role edit")) acts.appendChild(h("button", { class: "ghost small", text: "Edit", on: { click: function () { roleForm(root, r, mods); } } }));
        if (!r.is_super && can("role delete")) acts.appendChild(h("button", { class: "danger small", text: "Delete", on: { click: function () {
          confirmDo("Delete role " + r.label + "?", function () { api("DELETE", "/admin/roles/" + r.id).then(function (x) { toast(x.ok ? "Deleted" : errText(x), !x.ok); if (x.ok) pageRoles(root); }); });
        } } }));
        card.appendChild(h("div", { class: "item" }, h("div", { class: "main" }, h("div", { class: "t", text: r.label }),
          h("div", { class: "s", text: r.is_super ? "Full access · " + r.members + " member" + (r.members === 1 ? "" : "s") : r.permissions.length + " permissions · " + r.members + " member" + (r.members === 1 ? "" : "s") }),
          h("div", { style: "margin-top:8px" }, acts))));
      });
      root.appendChild(card);
    });
  }
  function roleForm(root, r, mods) {
    var have = r ? r.permissions : [];
    var name = text(r && r.name, "e.g. support"), label = text(r && r.label, "e.g. Support team");
    if (r) name.disabled = false;
    var groups = mods.map(function (m) {
      var c = checks(m.actions.map(function (a) { return [m.key + " " + a, a]; }), have);
      return { m: m, c: c };
    });
    var out = h("p", { class: "msg" });
    root.textContent = "";
    root.appendChild(head(r ? "Edit role" : "Add role", null, h("button", { class: "ghost", text: "Back", on: { click: function () { pageRoles(root); } } })));
    var card = h("div", { class: "card" }, h("div", { class: "grid2" }, field("Label", label), field("Short name", name, "Lowercase letters, numbers, dash.")), h("h3", { text: "Permissions" }));
    groups.forEach(function (g) { card.appendChild(h("div", { class: "perm-mod" }, h("div", { class: "name", text: g.m.label }), g.c.el)); });
    card.appendChild(out);
    var save = h("button", { text: "Save role", style: "width:100%;margin-top:14px" });
    save.addEventListener("click", function () {
      var perms = []; groups.forEach(function (g) { perms = perms.concat(g.c.get()); });
      save.disabled = true; msg(out, "");
      api(r ? "PUT" : "POST", "/admin/roles" + (r ? "/" + r.id : ""), { name: name.value.trim(), label: label.value.trim(), permissions: perms })
        .then(function (x) { save.disabled = false; if (x.ok) { toast("Saved"); pageRoles(root); } else msg(out, errText(x)); });
    });
    card.appendChild(save); root.appendChild(card);
  }

  // ---------- Sub-admins ----------
  function pageSubAdmins(root) {
    loading(root);
    Promise.all([api("GET", "/admin/sub-admins"), can("role list") ? api("GET", "/admin/roles") : Promise.resolve({ body: { data: [] } })]).then(function (res) {
      var list = (res[0].body && res[0].body.data) || [], roles = (res[1].body && res[1].body.data) || [];
      root.textContent = "";
      root.appendChild(head("Sub-admins", "People who can sign in to this dashboard.", can("subadmin add") ? h("button", { text: "Add sub-admin", on: { click: function () { subForm(root, null, roles); } } }) : null));
      var card = h("div", { class: "card" });
      list.forEach(function (u) {
        var acts = h("div", { class: "acts" });
        if (can("subadmin edit")) acts.appendChild(h("button", { class: "ghost small", text: "Edit", on: { click: function () { subForm(root, u, roles); } } }));
        if (can("subadmin delete") && u.id !== ME.id) acts.appendChild(h("button", { class: "danger small", text: "Delete", on: { click: function () {
          confirmDo("Delete " + u.email + "?", function () { api("DELETE", "/admin/sub-admins/" + u.id).then(function (x) { toast(x.ok ? "Deleted" : errText(x), !x.ok); if (x.ok) pageSubAdmins(root); }); });
        } } }));
        card.appendChild(h("div", { class: "item" },
          h("div", { class: "main" }, h("div", { class: "t", text: (u.first_name || "") + " " + (u.last_name || "") }), h("div", { class: "s", text: u.email + " · " + (u.role_label || "No role") }), h("div", { style: "margin-top:8px" }, acts)),
          h("span", { class: "pill " + (u.status === "active" ? "on" : ""), text: u.status })));
      });
      root.appendChild(card);
    });
  }
  function subForm(root, u, roles) {
    var f = {
      first: text(u && u.first_name), last: text(u && u.last_name), email: h("input", { type: "email", value: u ? u.email : "" }), user: text(u && u.username),
      phone: text(u && u.contact_number), role: select(roles.map(function (r) { return [r.id, r.label]; }), u && u.admin_role_id),
      status: select([["active", "Active"], ["inactive", "Switched off"]], u ? u.status : "active"), pass: h("input", { type: "password", autocomplete: "new-password" })
    };
    var out = h("p", { class: "msg" });
    root.textContent = "";
    root.appendChild(head(u ? "Edit sub-admin" : "Add sub-admin", null, h("button", { class: "ghost", text: "Back", on: { click: function () { pageSubAdmins(root); } } })));
    var card = h("div", { class: "card" }, h("div", { class: "grid2" }, field("First name", f.first), field("Last name", f.last), field("Email", f.email), field("Username", f.user), field("Phone", f.phone), field("Role", f.role)),
      field("Status", f.status), field(u ? "New password (leave blank to keep)" : "Password (10+ characters)", f.pass), out);
    var save = h("button", { text: "Save", style: "width:100%;margin-top:14px" });
    save.addEventListener("click", function () {
      var body = { first_name: f.first.value.trim(), last_name: f.last.value.trim(), email: f.email.value.trim(), username: f.user.value.trim(), contact_number: ns(f.phone), admin_role_id: Number(f.role.value), status: f.status.value };
      if (f.pass.value) body.password = f.pass.value; else if (!u) return msg(out, "Enter a password (10+ characters).");
      if (!body.admin_role_id) return msg(out, "Pick a role.");
      save.disabled = true; msg(out, "");
      api(u ? "PUT" : "POST", "/admin/sub-admins" + (u ? "/" + u.id : ""), body).then(function (x) { save.disabled = false; if (x.ok) { toast("Saved"); pageSubAdmins(root); } else msg(out, errText(x)); });
    });
    card.appendChild(save); root.appendChild(card);
  }

  // ---------- boot ----------
  if (location.hash === "#setup") showAuth("setup");
  else if (TOKEN) start();
  else showAuth("login");
})();
