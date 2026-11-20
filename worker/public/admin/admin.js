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
  function uploadFile(path, file) {
    return fetch("/api" + path, { method: "PUT", headers: Object.assign({ Accept: "application/json", "Content-Type": file.type || "application/octet-stream" }, TOKEN ? { Authorization: "Bearer " + TOKEN } : {}), body: file })
      .then(function (r) { return r.json().catch(function () { return {}; }).then(function (j) { return { status: r.status, ok: r.ok, body: j }; }); })
      .catch(function () { return { status: 0, ok: false, body: { message: "Network error. Try again." } }; });
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
    { id: "order-ride", label: "Order Ride", group: "Operations", perm: "ride_order list", render: pageOrderRide },
    { id: "route-stops", label: "Route stops", group: "Operations", perm: "ride_order list", render: pageRouteStops },
    { id: "push", label: "Push notifications", group: "System", perm: "push_settings list", render: pagePush },
    { id: "regions", label: "Regions", group: "Operations", perm: "region list", render: pageRegions },
    { id: "ride-options", label: "Ride options", group: "Operations", perm: "service_option list", render: pageOptions },
    { id: "payment-methods", label: "Payment methods", group: "Financial", perm: "payment_gateway list", render: pagePayments },
    { id: "transfers", label: "Wallet transfers", group: "Financial", perm: "wallet_transfer list", render: pageTransfers },
    { id: "paymyride", label: "PayMyRide", group: "Financial", perm: "paymyride list", render: pagePayMyRide },
    { id: "payouts", label: "Driver payouts", group: "Financial", perm: "payout list", render: pagePayouts },
    { id: "chat", label: "Ride chat", group: "Operations", perm: "ride_chat list", render: pageChat },
    { id: "calls", label: "Voice calls", group: "Operations", perm: "ride_call list", render: pageCalls },
    { id: "pickup", label: "Pickup codes", group: "Operations", perm: "pickup_code list", render: pagePickup },
    { id: "extras", label: "Extra charges", group: "Operations", perm: "ride_extra list", render: pageExtras },
    { id: "sos", label: "SOS alerts", group: "Safety", perm: "sos list", render: pageSos },
    { id: "complaints", label: "Complaints", group: "Safety", perm: "complaint list", render: pageComplaints },
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
      sosBadge();
      if (!window.__sosTimer) window.__sosTimer = setInterval(sosBadge, 20000);
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
    Promise.all([one, api("GET", "/admin/map-icons")]).then(function (both) {
      var r = both[0], iconList = (both[1].body && both[1].body.data) || [];
      var s = (r.body && r.body.data) || {};
      if (id && !r.ok) { toast("Ride type not found", true); return pageRideTypes(root); }
      var i18n = s.name_i18n || {}, hrs = s.working_hours;
      var f = {
        name: text(s.name), region_id: select(rt.regions.map(function (g) { return [g.id, g.name]; }), s.region_id || rt.region || (rt.regions[0] && rt.regions[0].id)),
        category: select(CATEGORIES, s.category || "car"), capacity: num(s.capacity == null ? 4 : s.capacity),
        description: text(s.description), icon_url: text(s.icon_url, "https://…"), photo_url: text(s.photo_url, "https://…"),
        map_icon_key: select([["", "Automatic (from category)"]].concat(iconList.map(function (ic) { return [ic.key, ic.label]; })), s.map_icon_key || ""),
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
      if (id && can("service edit")) {
        var iconFile = h("input", { type: "file", accept: "image/png,image/webp,image/jpeg", style: "display:none" });
        var iconBtn = h("button", { class: "small ghost", type: "button", text: "Upload ride type picture" });
        iconBtn.addEventListener("click", function () { iconFile.click(); });
        iconFile.addEventListener("change", function () {
          if (!iconFile.files[0]) return;
          uploadFile("/admin/services/" + id + "/icon", iconFile.files[0]).then(function (x) {
            if (x.ok) f.icon_url.value = x.body.icon_url || "";
            toast(x.ok ? "Picture saved" : errText(x), !x.ok);
          });
        });
        var iconReset = h("button", { class: "small ghost", type: "button", text: "Use built-in picture" });
        iconReset.addEventListener("click", function () {
          api("DELETE", "/admin/services/" + id + "/icon").then(function (x) { if (x.ok) f.icon_url.value = ""; toast(x.ok ? "Back to built-in" : errText(x), !x.ok); });
        });
        card.appendChild(h("div", { class: "row", style: "gap:8px;margin:4px 0 12px;align-items:center" }, iconFile, iconBtn, iconReset,
          h("span", { class: "muted", text: "Side-view picture on the rider's ride type list (PNG, WebP or JPG, under 1 MB). Separate from the map icon below." })));
      }
      card.appendChild(field("Vehicle icon on the map", f.map_icon_key, "Shown for the driver on the map. Upload pictures on the Maps page."));
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
          description: ns(f.description), icon_url: ns(f.icon_url), photo_url: ns(f.photo_url), map_icon_key: ns(f.map_icon_key), name_i18n: names,
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


  // ---------- Multi-stop route settings ----------
  function pageRouteStops(root) {
    loading(root);
    api("GET", "/admin/ride-stop-settings").then(function (r) {
      var d = r.body && r.body.data;
      root.textContent = "";
      root.appendChild(head("Route stops", "Control how many additional destinations passengers can add to one trip."));
      if (!r.ok || !d) {
        root.appendChild(h("p", { class: "msg err", text: errText(r) }));
        return;
      }
      var limit = h("input", { type: "number", min: "0", max: "20", step: "1", value: String(d.max_additional_stops) });
      var out = h("p", { class: "msg", "aria-live": "polite" });
      var card = h("div", { class: "card" },
        h("h3", { text: "Maximum additional stops per trip" }),
        h("p", { class: "muted", text: "Pickup and final destination are not counted. Set 0 to disable additional stops. The server enforces this limit for every booking." }),
        field("Additional stops allowed (0–20)", limit),
        h("p", { class: "muted", text: "Current limit: " + d.max_additional_stops }),
        out);
      if (can("ride_order edit")) {
        var save = h("button", { text: "Save route stop limit", class: "small" });
        save.addEventListener("click", function () {
          var value = Number(limit.value);
          if (!Number.isInteger(value) || value < 0 || value > 20) { msg(out, "Enter a whole number from 0 to 20."); return; }
          save.disabled = true;
          api("PUT", "/admin/ride-stop-settings", { max_additional_stops: value }).then(function (x) {
            save.disabled = false;
            if (x.ok) { toast("Route stop limit saved"); pageRouteStops(root); }
            else msg(out, errText(x));
          });
        });
        card.appendChild(save);
      } else {
        card.appendChild(h("p", { class: "muted", text: "You have view-only access to this setting." }));
      }
      root.appendChild(card);
    });
  }

  // ---------- Push notifications (OneSignal) ----------
  function pagePush(root) {
    loading(root);
    api("GET", "/admin/push-settings").then(function (r) {
      var d = (r.body || {}).data;
      root.textContent = "";
      root.appendChild(head("Push notifications", "Alerts on people's phones, such as a document request or an application decision. Uses OneSignal."));
      if (!r.ok || !d) { root.appendChild(h("p", { class: "msg", text: errText(r) })); return; }
      root.appendChild(h("div", { class: "card" },
        h("div", { class: "t", text: d.app_id && d.key_set ? "Push is switched on" : "Push is not set up yet" }),
        h("p", { class: "muted", text: "App ID: " + (d.app_id || "not set") + " · REST key: " + (d.key_set ? "saved (ends " + d.key_last4 + ")" : "not set") + " · Phones registered: " + d.devices }),
        d.app_id && d.key_set ? null : h("p", { class: "muted", text: "In OneSignal: create an app for DROP (Settings, Keys and IDs), connect Firebase for Android, then paste the App ID and the REST API Key below. The key is stored encrypted and is never shown again." })));
      var appId = text(d.app_id || "", "OneSignal App ID"), key = h("input", { type: "password", placeholder: d.key_set ? "Saved. Paste a new key only to replace it." : "OneSignal REST API Key", autocomplete: "off" });
      var out = h("p", { class: "msg" });
      var card = h("div", { class: "card" }, field("OneSignal App ID", appId), field("REST API Key", key));
      if (can("push_settings edit")) {
        var save = h("button", { text: "Save", class: "small", style: "margin-top:10px" });
        save.addEventListener("click", function () {
          var body = {}; if (appId.value.trim()) body.app_id = appId.value.trim(); if (key.value.trim()) body.rest_key = key.value.trim();
          if (!body.app_id && !body.rest_key) return msg(out, "Enter the App ID or the REST key.");
          save.disabled = true;
          api("PUT", "/admin/push-settings", body).then(function (x) { save.disabled = false; if (x.ok) { toast("Saved"); pagePush(root); } else msg(out, errText(x)); });
        });
        card.appendChild(save);
        var email = h("input", { type: "email", placeholder: "Email of someone with the new app installed" });
        var test = h("button", { class: "ghost small", text: "Send test", style: "margin-top:10px" });
        test.addEventListener("click", function () {
          if (!email.value.trim()) return msg(out, "Enter an email to send the test to.");
          test.disabled = true;
          api("POST", "/admin/push-settings/test", { email: email.value.trim() }).then(function (x) { test.disabled = false; msg(out, x.ok ? x.body.message : errText(x)); });
        });
        card.appendChild(h("div", { style: "margin-top:18px" }, field("Send a test notification", email), test));
      }
      card.appendChild(out);
      root.appendChild(card);
    });
  }

  // ---------- Regions ----------
  function pageRegions(root) {
    loading(root);
    api("GET", "/admin/regions").then(function (r) {
      var list = (r.body && r.body.data) || [];
      root.textContent = "";
      root.appendChild(head("Regions", "The areas where Drop operates.", can("region add") ? h("button", { text: "Add region", on: { click: function () { regionForm(root, null, list); } } }) : null));
      var card = h("div", { class: "card" });
      if (!list.length) card.appendChild(h("div", { class: "empty", text: "No regions yet. Add your first operating area." }));
      list.forEach(function (g) {
        var acts = h("div", { class: "acts" });
        if (can("region edit")) acts.appendChild(h("button", { class: "ghost small", text: "Edit", on: { click: function () { regionForm(root, g, list.filter(function (x) { return x.id !== g.id; })); } } }));
        if (can("region delete")) acts.appendChild(h("button", { class: "danger small", text: "Delete", on: { click: function () {
          confirmDo("Delete region " + g.name + "?", function () { api("DELETE", "/admin/regions/" + g.id).then(function (x) { toast(x.ok ? "Deleted" : errText(x), !x.ok); if (x.ok) pageRegions(root); }); });
        } } }));
        card.appendChild(h("div", { class: "item" },
          h("div", { class: "main" }, h("div", { class: "t", text: g.name || "Region " + g.id }),
            h("div", { class: "s", text: g.ride_types + " ride type" + (g.ride_types === 1 ? "" : "s") + " · " + String(g.currency || "NGN").trim() + " · " + g.timezone + " · " + g.distance_unit + (g.coordinates ? " · border drawn" : " · no border (covers everywhere)") }),
            h("div", { class: "s", text: g.drivers + " approved driver" + (g.drivers === 1 ? "" : "s") + " · " + g.drivers_online + " online now · " + g.people + " people in this region" }),
            h("div", { style: "margin-top:8px" }, acts)),
          h("span", { class: "pill " + (g.status ? "on" : ""), text: g.status ? "On" : "Off" })));
      });
      root.appendChild(card);
    });
  }

  // ---------- Region border map (Leaflet from cdnjs) ----------
  function loadLeaflet() {
    return new Promise(function (resolve, reject) {
      if (window.L) return resolve(window.L);
      var css = document.createElement("link"); css.rel = "stylesheet"; css.href = "https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/leaflet.min.css"; document.head.appendChild(css);
      var js = document.createElement("script"); js.src = "https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/leaflet.min.js";
      js.onload = function () { resolve(window.L); }; js.onerror = function () { reject(new Error("map")); };
      document.head.appendChild(js);
    });
  }
  /** Approximate area of a drawn border in km². */
  function areaKm2(pts) {
    if (pts.length < 3) return 0;
    var lat0 = pts.reduce(function (a, p) { return a + p.lat; }, 0) / pts.length, kx = 111.32 * Math.cos(lat0 * Math.PI / 180), ky = 110.57, a = 0;
    for (var i = 0; i < pts.length; i++) { var p = pts[i], q = pts[(i + 1) % pts.length]; a += (p.lng * kx) * (q.lat * ky) - (q.lng * kx) * (p.lat * ky); }
    return Math.abs(a) / 2;
  }
  /**
   * A map where the admin taps point after point to draw the region's border. Points can be dragged;
   * other regions show as grey outlines. state.pts always holds the current border.
   */
  function borderMap(box, state, others, onChange) {
    loadLeaflet().then(function (L) {
      var has = state.pts.length > 0;
      var map = L.map(box).setView(has ? [state.pts[0].lat, state.pts[0].lng] : [9.0765, 7.3986], has ? 12 : 6);
      var street = L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", { maxZoom: 19, attribution: "© OpenStreetMap" }).addTo(map);
      var sat = L.tileLayer("https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}", { maxZoom: 19, attribution: "Esri" });
      L.control.layers({ "Street": street, "Satellite": sat }, null, { position: "topright" }).addTo(map);
      others.forEach(function (g) {
        if (g.coordinates && g.coordinates.length > 2) L.polygon(g.coordinates.map(function (p) { return [p.lat, p.lng]; }), { color: "#888", weight: 2, dashArray: "5 5", fillOpacity: 0.05, interactive: false }).addTo(map).bindTooltip(g.name || "", { permanent: false });
      });
      var poly = L.polygon([], { color: "#FC9600", weight: 3, fillOpacity: 0.18, interactive: false }).addTo(map);
      var handles = [];
      function ll() { return state.pts.map(function (p) { return [p.lat, p.lng]; }); }
      function redraw() {
        poly.setLatLngs(ll());
        handles.forEach(function (m) { map.removeLayer(m); }); handles = [];
        state.pts.forEach(function (p, i) {
          var m = L.marker([p.lat, p.lng], { draggable: true, icon: L.divIcon({ className: "vtx", html: "<span>" + (i + 1) + "</span>", iconSize: [28, 28] }) }).addTo(map);
          m.on("drag", function (e) { var x = e.target.getLatLng(); state.pts[i] = { lat: x.lat, lng: x.lng }; poly.setLatLngs(ll()); });
          m.on("dragend", function () { onChange(); });
          m.on("contextmenu dblclick", function (e) { L.DomEvent.stop(e); state.pts.splice(i, 1); redraw(); });
          handles.push(m);
        });
        onChange();
      }
      map.on("click", function (e) { state.pts.push({ lat: Math.round(e.latlng.lat * 1e6) / 1e6, lng: Math.round(e.latlng.lng * 1e6) / 1e6 }); redraw(); });
      state.undo = function () { state.pts.pop(); redraw(); };
      state.clear = function () { state.pts = []; redraw(); };
      state.reload = function (pts) { state.pts = pts; redraw(); if (pts.length) map.fitBounds(poly.getBounds(), { padding: [30, 30] }); };
      state.goto = function (lat, lng, bounds) { if (bounds) map.fitBounds(bounds); else map.setView([lat, lng], 13); };
      if (has) { redraw(); map.fitBounds(poly.getBounds(), { padding: [30, 30] }); } else onChange();
      setTimeout(function () { map.invalidateSize(); }, 200);
    }).catch(function () { box.textContent = "The map could not load. Check your connection, or type the points in the text box below."; });
  }

  function regionForm(root, g, others) {
    var pts = (g && g.coordinates || []).map(function (p) { return p.lat + ", " + p.lng; }).join("\n");
    var f = {
      name: text(g && g.name), unit: select([["km", "Kilometres"], ["mile", "Miles"]], g ? g.distance_unit : "km"),
      tz: text(g ? g.timezone : "Africa/Lagos"), cur: select(CURRENCY_OPTIONS, g ? String(g.currency || "NGN").trim() : "NGN"), poly: h("textarea", { placeholder: "9.0765, 7.3986\n9.1000, 7.4500\n9.0400, 7.5000" }),
      status: h("input", { type: "checkbox", checked: g ? g.status : true })
    };
    f.poly.value = pts;
    others = others || [];
    var state = { pts: ((g && g.coordinates) || []).map(function (p) { return { lat: Number(p.lat), lng: Number(p.lng) }; }) };
    var mapBox = h("div", { class: "borderbox", text: "Loading map…" });
    var mapInfo = h("div", { class: "s", style: "margin-top:6px" });
    function syncInfo() {
      f.poly.value = state.pts.map(function (p) { return p.lat + ", " + p.lng; }).join("\n");
      mapInfo.textContent = state.pts.length ? state.pts.length + " point" + (state.pts.length === 1 ? "" : "s") + (state.pts.length > 2 ? " · about " + areaKm2(state.pts).toFixed(1) + " km²" : " · add at least 3") : "No border drawn yet.";
    }
    var search = h("input", { type: "search", placeholder: "Search a city or place" });
    var mapBar = h("div", { class: "acts", style: "margin:8px 0" }, search,
      h("button", { class: "ghost small", type: "button", text: "Go", on: { click: function () {
        var q = search.value.trim(); if (!q) return;
        fetch("https://nominatim.openstreetmap.org/search?format=json&limit=1&q=" + encodeURIComponent(q)).then(function (r) { return r.json(); }).then(function (x) {
          if (!x.length) return toast("Place not found", true);
          var b = x[0].boundingbox; if (state.goto) state.goto(Number(x[0].lat), Number(x[0].lon), [[Number(b[0]), Number(b[2])], [Number(b[1]), Number(b[3])]]);
        }).catch(function () { toast("Search is not available right now", true); });
      } } }),
      h("button", { class: "ghost small", type: "button", text: "My location", on: { click: function () {
        if (!navigator.geolocation) return toast("Location is not available", true);
        navigator.geolocation.getCurrentPosition(function (p) { if (state.goto) state.goto(p.coords.latitude, p.coords.longitude); }, function () { toast("Allow location in your browser first", true); });
      } } }),
      h("button", { class: "ghost small", type: "button", text: "Undo point", on: { click: function () { if (state.undo) state.undo(); } } }),
      h("button", { class: "danger small", type: "button", text: "Clear border", on: { click: function () { if (state.clear) state.clear(); } } }));
    f.poly.addEventListener("change", function () {
      var pts = f.poly.value.split("\n").map(function (x) { return x.trim(); }).filter(Boolean).map(function (l) { var q = l.split(/[ ,]+/); return { lat: Number(q[0]), lng: Number(q[1]) }; });
      if (pts.every(function (q) { return isFinite(q.lat) && isFinite(q.lng); })) { if (state.reload) state.reload(pts); else state.pts = pts; syncInfo(); }
    });
    var out = h("p", { class: "msg" });
    root.textContent = "";
    root.appendChild(head(g ? "Edit region" : "Add region", null, h("button", { class: "ghost", text: "Back", on: { click: function () { pageRegions(root); } } })));
    var card = h("div", { class: "card" },
      field("Name", f.name), h("div", { class: "grid2" }, field("Distance unit", f.unit), field("Time zone", f.tz)), field("Currency", f.cur, "Fares in this region are in this currency. Enter the ride type prices in it. Passengers pay from their wallet only when their wallet is in the same currency; otherwise they pay cash."),
      h("div", { class: "f" }, h("label", { class: "f", text: "Region border" }),
        h("div", { class: "hint", text: "Tap the map to add points around the area, one after another. Drag a point to move it; double-tap or right-click a point to remove it. Passengers and drivers inside this border are asked to switch to this region. With no border the region covers everywhere that is not inside another region." }),
        mapBar, mapBox, mapInfo,
        h("details", { style: "margin-top:10px" }, h("summary", { text: "Edit points as text" }), f.poly)),
      h("div", { class: "row" }, h("div", { text: "Region is active" }), h("label", { class: "switch" }, f.status, h("span"))), out);
    var save = h("button", { text: "Save", style: "width:100%;margin-top:14px" });
    save.addEventListener("click", function () {
      var coords = state.pts.length ? state.pts.slice() : null;
      if (coords && coords.length < 3) return msg(out, "Draw at least 3 points for the border, or clear it.");
      if (!f.name.value.trim()) return msg(out, "Enter a name.");
      save.disabled = true; msg(out, "");
      api(g ? "PUT" : "POST", "/admin/regions" + (g ? "/" + g.id : ""), { name: f.name.value.trim(), distance_unit: f.unit.value, timezone: f.tz.value.trim(), currency: f.cur.value, status: f.status.checked, coordinates: coords })
        .then(function (r) { save.disabled = false; if (r.ok) { toast("Saved"); pageRegions(root); } else msg(out, errText(r)); });
    });
    card.appendChild(save); root.appendChild(card);
    mapBox.textContent = "";
    borderMap(mapBox, state, others, syncInfo);
    syncInfo();
  }

  // ---------- Ride options ----------
  // ---------- Extra charges: master switch, limits and the list of charge types (Extra charges page) ----------
  function extrasCard(root) {
    var card = h("div", { class: "card" }, h("div", { class: "t", text: "Extra charges in the app" }), h("p", { class: "muted", text: "A driver can add a charge (fuel hike, toll, parking...) after accepting a ride, before arriving at the pickup. The passenger approves it and pays from the wallet or in cash. Switch it off and drivers no longer see the button." }));
    root.appendChild(card);
    api("GET", "/admin/extras-settings").then(function (r) {
      var s = (r.body || {}).data || { enabled: true, max_percent: 20, window_minutes: 10 };
      var on = select([["1", "On"], ["0", "Off"]], s.enabled === false ? "0" : "1");
      var max = num(String(s.max_percent), "20"), win = num(String(s.window_minutes), "10");
      var out = h("p", { class: "msg" });
      card.appendChild(field("Extra charges feature", on));
      card.appendChild(h("div", { class: "grid2" }, field("Maximum (% of the fare)", max, "Total extras on one trip cannot pass this."), field("Minutes for the passenger to answer", win, "1 to 60.")));
      if (can("ride_extra edit")) {
        var save = h("button", { text: "Save", class: "small", style: "margin-top:10px" });
        save.addEventListener("click", function () {
          save.disabled = true;
          api("PUT", "/admin/extras-settings", { enabled: on.value === "1", max_percent: nn(max), window_minutes: nn(win) }).then(function (x) { save.disabled = false; if (x.ok) toast("Saved"); else msg(out, errText(x)); });
        });
        card.appendChild(save);
      } else { on.disabled = true; max.disabled = true; win.disabled = true; }
      card.appendChild(out);
    });
  }

  function extraTypesCard(root) {
    var card = h("div", { class: "card" }, h("div", { class: "t", text: "Charge types" }), h("p", { class: "muted", text: "What a driver can choose from. For each one: turn it on or off, choose whether DROP takes its commission on it, and optionally set the most a driver can charge. When commission is on, it uses the ride type's own commission rate and is added to the trip's commission." }));
    root.appendChild(card);
    api("GET", "/admin/extra-types").then(function (r) {
      var list = (r.body || {}).data || [];
      list.forEach(function (t) {
        var row = h("div", { class: "row", style: "display:flex;align-items:center;gap:10px;padding:10px 0;border-top:1px solid var(--line,#eee);flex-wrap:wrap" });
        row.appendChild(h("div", { style: "flex:1;min-width:150px" }, h("div", { class: "t", text: t.name }),
          h("div", { class: "s", text: (t.active ? "On" : "Hidden") + " \u00B7 " + (t.take_commission ? "DROP takes commission" : "No commission") + " \u00B7 " + (t.max_amount ? "Max " + Number(t.max_amount).toLocaleString() : "No limit") })));
        if (can("ride_extra edit")) {
          var tog = h("button", { text: t.active ? "Hide" : "Show", class: "small secondary" });
          tog.addEventListener("click", function () { api("PUT", "/admin/extra-types/" + t.id, { active: !t.active }).then(function (x) { if (x.ok) pageExtras(root.parentNode || root); else toast(errText(x), true); }); });
          var com = h("button", { text: t.take_commission ? "Stop commission" : "Take commission", class: "small secondary" });
          com.addEventListener("click", function () { api("PUT", "/admin/extra-types/" + t.id, { take_commission: !t.take_commission }).then(function (x) { if (x.ok) { toast("Saved"); pageExtras(root.parentNode || root); } else toast(errText(x), true); }); });
          var ed = h("button", { text: "Edit", class: "small secondary" });
          ed.addEventListener("click", function () {
            var n = window.prompt("Name", t.name); if (n === null) return;
            var m = window.prompt("Most a driver can charge for this (empty = no limit)", t.max_amount || ""); if (m === null) return;
            api("PUT", "/admin/extra-types/" + t.id, { name: n, max_amount: m }).then(function (x) { if (x.ok) { toast("Saved"); pageExtras(root.parentNode || root); } else toast(errText(x), true); });
          });
          var del = h("button", { text: "Delete", class: "small danger" });
          del.addEventListener("click", function () { confirmDo("Delete " + t.name + "? Past charges keep their name.", function () { api("DELETE", "/admin/extra-types/" + t.id).then(function (x) { if (x.ok) pageExtras(root.parentNode || root); else toast(errText(x), true); }); }); });
          row.appendChild(tog); row.appendChild(com); row.appendChild(ed); row.appendChild(del);
        }
        card.appendChild(row);
      });
      if (!list.length) card.appendChild(h("div", { class: "empty", text: "No charge types yet. Drivers cannot add extra charges until you add one." }));
      if (can("ride_extra edit")) {
        var n = text("", "e.g. Airport fee"), mx = num("", "Limit (optional)"), cm = select([["0", "No commission"], ["1", "DROP takes commission"]], "0"), out = h("p", { class: "msg" });
        var add = h("button", { text: "Add charge type", class: "small", style: "margin-top:10px" });
        add.addEventListener("click", function () {
          if (!n.value.trim()) return msg(out, "Enter a name.");
          add.disabled = true;
          api("POST", "/admin/extra-types", { name: n.value.trim(), take_commission: cm.value === "1", max_amount: mx.value }).then(function (x) { add.disabled = false; if (x.ok) { toast("Added"); pageExtras(root.parentNode || root); } else msg(out, errText(x)); });
        });
        card.appendChild(h("div", { style: "border-top:1px solid var(--line,#eee);margin-top:10px;padding-top:10px" }, h("div", { class: "t", text: "Add a charge type" }), field("Name", n), h("div", { class: "grid2" }, field("Commission", cm), field("Limit", mx)), add, out));
      }
    });
  }

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

  // ---------- Trip ETA switches (shown on the Maps page) ----------
  function etaCard(root) {
    var card = h("div", { class: "card" }, h("div", { class: "t", text: "Trip ETA" }), h("p", { class: "muted", text: "Show how many minutes a trip has left, and the arrival time. It is an estimate from the driver's last location." }));
    root.appendChild(card);
    api("GET", "/admin/eta-settings").then(function (r) {
      var s = (r.body || {}).data || { rider: true, driver: true };
      var rider = select([["1", "On"], ["0", "Off"]], s.rider === false ? "0" : "1");
      var driver = select([["1", "On"], ["0", "Off"]], s.driver === false ? "0" : "1");
      var out = h("p", { class: "msg" });
      card.appendChild(field("Passenger ETA (trip screen and fare list)", rider));
      card.appendChild(field("Driver ETA (trip screen and request card)", driver));
      if (can("map_settings edit")) {
        var save = h("button", { text: "Save", class: "small", style: "margin-top:10px" });
        save.addEventListener("click", function () {
          save.disabled = true;
          api("PUT", "/admin/eta-settings", { rider: rider.value === "1", driver: driver.value === "1" }).then(function (x) { save.disabled = false; if (x.ok) toast("Saved"); else msg(out, errText(x)); });
        });
        card.appendChild(save);
      } else { rider.disabled = true; driver.disabled = true; }
      card.appendChild(out);
    });
  }

  // ---------- Maps (Google / OpenStreetMap / Mapbox) ----------
  function pageMaps(root) {
    loading(root);
    api("GET", "/admin/map-settings").then(function (r) {
      var d = (r.body || {}).data;
      if (!r.ok || !d) { root.textContent = ""; root.appendChild(head("Maps", "")); root.appendChild(h("p", { class: "msg", text: errText(r) })); return; }
      root.textContent = "";
      root.appendChild(head("Maps", "Choose the map renderer used by the unified passenger and driver app. Existing providers remain available."));
      var status = h("div", { class: "card" });
      status.appendChild(h("div", { class: "t", text: "Active map provider: " + (d.active === "google" ? "Google Maps" : d.active === "mapbox" ? "Mapbox" : "OpenStreetMap / MapLibre") }));
      status.appendChild(h("p", { class: "muted", text: "Google server key: " + (d.google_server_key_set ? "set" : "not set") + (d.google_failed_recently ? " · Google recently failed (" + d.google_failed_at + ")" : "") }));
      if (d.fallback_reason) status.appendChild(h("p", { class: "msg", text: d.fallback_reason }));
      root.appendChild(status);
      etaCard(root);
      var provider = select([["auto", "Automatic (Google when configured, otherwise OpenStreetMap)"], ["google", "Google Maps"], ["osm", "OpenStreetMap / MapLibre"], ["mapbox", "Mapbox"]], d.provider);
      var tiles = text(d.osm_tile_url, "https://tile.openstreetmap.org/{z}/{x}/{y}.png");
      var routing = text(d.osm_routing_url, "https://router.project-osrm.org");
      var enabled = h("input", { type: "checkbox" }); enabled.checked = !!d.mapbox_enabled;
      var borders = h("input", { type: "checkbox" }); borders.checked = !!d.mapbox_region_bordering_enabled; borders.disabled = !enabled.checked;
      Array.from(provider.options).forEach(function (option) { if (option.value === "mapbox") option.disabled = !d.mapbox_enabled || !d.mapbox_configured; });
      enabled.addEventListener("change", function () {
        borders.disabled = !enabled.checked;
        if (!enabled.checked) borders.checked = false;
        Array.from(provider.options).forEach(function (option) { if (option.value === "mapbox") option.disabled = !enabled.checked || !d.mapbox_configured; });
      });
      var style = text(d.mapbox_style_uri || "mapbox://styles/mapbox/streets-v12");
      var token = h("input", { type: "password", autocomplete: "new-password", placeholder: d.mapbox_public_token_masked || "pk...." });
      var show = h("button", { class: "ghost small", type: "button", text: "Show" });
      show.addEventListener("click", function () { token.type = token.type === "password" ? "text" : "password"; show.textContent = token.type === "password" ? "Show" : "Hide"; });
      var tokenStatus = h("p", { class: "muted", text: "Public token: " + (d.mapbox_public_token_set ? d.mapbox_public_token_masked + " saved" : "not configured") + " · Connection: " + (d.mapbox_connection_status || "not tested") + (d.mapbox_last_verified_at ? " · Last verified: " + d.mapbox_last_verified_at : "") + (d.mapbox_last_updated_at ? " · Last configuration update: " + d.mapbox_last_updated_at : "") });
      var out = h("p", { class: "msg" });
      var card = h("div", { class: "card" },
        field("Map service", provider, "Mapbox can be selected only after its public token passes Test Connection."),
        field("OpenStreetMap tile address", tiles, "Existing MapLibre/raster fallback. Keep the {z}, {x} and {y} placeholders."),
        field("OpenStreetMap route service", routing, "Routing remains separate from map rendering."),
        h("h3", { text: "Mapbox configuration" }),
        h("p", { class: "muted", text: "Use a restricted public pk. token. No secret sk. token is required for mobile map rendering." }),
        h("div", { class: "row" }, h("span", { text: "Enable Mapbox" }), h("label", { class: "switch" }, enabled, h("span"))),
        field("Mapbox public access token", token, "Enter a new token to replace the saved token. Leave blank to keep it."),
        h("div", { class: "row", style: "gap:8px;flex-wrap:wrap" }, show,
          h("button", { class: "ghost small", text: "Test Connection", on: { click: function () {
            saveMapSettings(null, function () {
              api("POST", "/admin/map-settings/test", {}).then(function (x) { msg(out, x.ok ? ((x.body || {}).message || "Connection successful.") : errText(x), x.ok); if (x.ok) pageMaps(root); });
            });
          } } }),
          h("button", { class: "ghost small", text: "Remove saved token", on: { click: function () {
            confirmDo("Remove the saved Mapbox public token?", function () { token.value = ""; saveMapSettings({ mapbox_public_token: null }); });
          } } })),
        tokenStatus,
        field("Mapbox style URI (optional)", style, "Default: mapbox://styles/mapbox/streets-v12. You may use a Mapbox Studio style."),
        h("div", { class: "row" }, h("span", { text: "Use Mapbox for Region Bordering" }), h("label", { class: "switch" }, borders, h("span"))),
        h("p", { class: "muted", text: "When enabled, existing service-region polygons are supplied as GeoJSON for Mapbox-compatible point-in-polygon and boundary-proximity checks, regardless of the selected map renderer. If Mapbox is selected, the same polygons are also drawn as fill/outline layers. Region membership, ride eligibility and switching remain controlled by the Worker/PostGIS backend." }));
      function saveMapSettings(extra, after) {
        var body = Object.assign({ provider: provider.value, osm_tile_url: tiles.value.trim(), osm_routing_url: routing.value.trim(), mapbox_enabled: enabled.checked, mapbox_region_bordering_enabled: borders.checked, mapbox_style_uri: style.value.trim() }, extra || {});
        if (!Object.prototype.hasOwnProperty.call(extra || {}, "mapbox_public_token") && token.value.trim()) body.mapbox_public_token = token.value.trim();
        api("PUT", "/admin/map-settings", body).then(function (x) {
          if (x.ok) { if (after) after(); else { toast("Saved"); pageMaps(root); } }
          else msg(out, errText(x));
        });
      }
      if (!can("map_settings edit")) card.querySelectorAll("input,select,button").forEach(function (control) { control.disabled = true; });
      if (!d.encryption_configured) card.appendChild(h("p", { class: "msg", text: "Configure SETTINGS_ENCRYPTION_KEY (32+ characters) in the Cloudflare Worker before saving Mapbox credentials." }));
      if (can("map_settings edit")) {
        var save = h("button", { text: "Save Configuration", class: "small", style: "margin-top:10px" });
        save.addEventListener("click", function () { save.disabled = true; saveMapSettings(); setTimeout(function () { save.disabled = false; }, 500); });
        card.appendChild(save);
      }
      card.appendChild(out); root.appendChild(card); mapIconsCard(root);
    });
  }

  /** Vehicle pictures drawn on the map. Built-in ones are used until a picture is uploaded here. */
  function mapIconsCard(root) {
    var card = h("div", { class: "card" });
    root.appendChild(card);
    function draw() {
      api("GET", "/admin/map-icons").then(function (r) {
        card.textContent = "";
        card.appendChild(h("h3", { text: "Vehicle icons on the map" }));
        card.appendChild(h("p", { class: "muted", text: "These show the driver's vehicle on every map (Google, OpenStreetMap). Built-in pictures are used until you upload your own. Use a PNG or WebP with a transparent background, the vehicle seen from above with the front pointing up, at least 128 px wide, under 1 MB. The app resizes it automatically. Then choose the icon on each ride type." }));
        if (!r.ok) { card.appendChild(h("p", { class: "msg", text: errText(r) })); return; }
        var grid = h("div", { class: "grid2" });
        (r.body.data || []).forEach(function (ic) {
          var img = h("img", { style: "width:64px;height:64px;object-fit:contain;background:#f1f1f1;border-radius:8px" });
          if (ic.url) img.src = ic.url; else img.alt = "built-in";
          var row = h("div", { class: "row", style: "gap:12px;align-items:center;margin-bottom:10px" }, img,
            h("div", { style: "flex:1" }, h("div", { class: "t", text: ic.label }), h("div", { class: "muted", text: ic.url ? "Your picture" : "Built-in picture" })));
          if (can("map_settings edit")) {
            var file = h("input", { type: "file", accept: "image/png,image/webp", style: "display:none" });
            var up = h("button", { class: "small ghost", text: ic.url ? "Replace" : "Upload" });
            up.addEventListener("click", function () { file.click(); });
            file.addEventListener("change", function () {
              if (!file.files[0]) return;
              up.disabled = true;
              uploadFile("/admin/map-icons/" + ic.key + "/image", file.files[0]).then(function (x) { toast(x.ok ? "Picture saved" : errText(x), !x.ok); draw(); });
            });
            row.appendChild(file); row.appendChild(up);
            if (ic.url) row.appendChild(h("button", { class: "small ghost", text: "Reset", on: { click: function () { api("DELETE", "/admin/map-icons/" + ic.key + "/image").then(function (x) { toast(x.ok ? "Back to built-in" : errText(x), !x.ok); draw(); }); } } }));
            if (!ic.builtin) row.appendChild(h("button", { class: "small ghost", text: "Delete", on: { click: function () { confirmDo("Delete this icon?", function () { api("DELETE", "/admin/map-icons/" + ic.key).then(function (x) { toast(x.ok ? "Deleted" : errText(x), !x.ok); draw(); }); }); } } }));
          }
          grid.appendChild(row);
        });
        card.appendChild(grid);
        if (can("map_settings edit")) {
          var name = text("", "New icon name, e.g. Ambulance");
          var add = h("button", { class: "small", text: "Add icon slot" });
          add.addEventListener("click", function () {
            if (!name.value.trim()) return;
            api("POST", "/admin/map-icons", { label: name.value.trim() }).then(function (x) { toast(x.ok ? "Added. Now upload its picture." : errText(x), !x.ok); draw(); });
          });
          card.appendChild(h("div", { class: "row", style: "gap:8px;margin-top:10px" }, name, add));
        }
      });
    }
    draw();
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
                window.prompt("Temporary password for " + (x.body.name || "this user") + " (shown once). Copy it and send it to them privately. They type it on the normal Log in screen (not on Reset password), then change it in their profile:", x.body.temporary_password);
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

  // ---------- Driver payouts (pay by hand, then mark paid) ----------
  var po = { status: "pending", page: 1 };
  function pagePayouts(root) {
    loading(root);
    api("GET", "/admin/payouts?status=" + po.status + "&page=" + po.page).then(function (r) {
      var b = r.body || {}, s = b.settings || {}, list = b.data || [], pg = b.pagination || { page: 1, total_pages: 1, total: 0 };
      root.textContent = "";
      root.appendChild(head("Driver payouts", "When a driver asks to be paid, the amount leaves their wallet at once. Send the money to the bank account shown, then mark it paid. If you decline, it goes back to their wallet."));
      var en = select([["1", "On"], ["0", "Paused"]], s.enabled === false ? "0" : "1"), min = num(s.min_amount), out = h("p", { class: "msg" });
      var sc = h("div", { class: "card" }, field("Payout requests", en), field("Smallest payout (\u20A6)", min));
      if (can("payout edit")) {
        var sv = h("button", { text: "Save", class: "small", style: "margin-top:10px" });
        sv.addEventListener("click", function () {
          sv.disabled = true;
          api("PUT", "/admin/payouts/settings", { enabled: en.value === "1", min_amount: nn(min) }).then(function (x) { sv.disabled = false; if (x.ok) toast("Saved"); else msg(out, errText(x)); });
        });
        sc.appendChild(sv);
      }
      sc.appendChild(out); root.appendChild(sc);
      var tabs = h("div", { style: "display:flex;gap:8px;margin:12px 0" });
      [["pending", "Waiting"], ["paid", "Paid"], ["declined", "Declined"]].forEach(function (t) {
        var bt = h("button", { text: t[1], class: "small" + (po.status === t[0] ? "" : " secondary") });
        bt.addEventListener("click", function () { po.status = t[0]; po.page = 1; pagePayouts(root); });
        tabs.appendChild(bt);
      });
      root.appendChild(tabs);
      var card = h("div", { class: "card" }, h("div", { class: "t", text: pg.total + " request" + (pg.total === 1 ? "" : "s") }));
      if (!list.length) card.appendChild(h("div", { class: "empty", text: "Nothing here." }));
      list.forEach(function (p) {
        var row = h("div", { class: "row", style: "padding:10px 0;border-top:1px solid var(--line,#eee)" },
          h("div", { class: "t", text: "\u20A6" + Number(p.amount).toLocaleString() + " \u00B7 " + (p.driver || p.username) }),
          h("div", { class: "s", text: p.bank_name + " \u00B7 " + p.account_number + " \u00B7 " + p.account_name }),
          h("div", { class: "s", text: String(p.created_at).slice(0, 16).replace("T", " ") + (p.admin_note ? " \u00B7 " + p.admin_note : "") }));
        if (p.status === "pending" && can("payout edit")) {
          var paid = h("button", { text: "Mark as paid", class: "small", style: "margin-top:8px" });
          paid.addEventListener("click", function () {
            if (!window.confirm("Confirm you sent \u20A6" + Number(p.amount).toLocaleString() + " to " + p.account_name + " (" + p.account_number + ")?")) return;
            api("PUT", "/admin/payouts/" + p.id, { action: "paid" }).then(function (x) { toast(x.ok ? x.body.message : errText(x), !x.ok); if (x.ok) pagePayouts(root); });
          });
          var dec = h("button", { text: "Decline", class: "small secondary", style: "margin:8px 0 0 8px" });
          dec.addEventListener("click", function () {
            var note = window.prompt("Why is this payout declined? The driver will see this."); if (!note) return;
            api("PUT", "/admin/payouts/" + p.id, { action: "declined", note: note }).then(function (x) { toast(x.ok ? x.body.message : errText(x), !x.ok); if (x.ok) pagePayouts(root); });
          });
          row.appendChild(paid); row.appendChild(dec);
        }
        card.appendChild(row);
      });
      root.appendChild(card);
    });
  }

  // ---------- SOS alerts and complaints ----------
  function pageChat(root) {
    loading(root);
    root.textContent = "";
    root.appendChild(head("Ride chat", "Passengers and their assigned driver can message each other, and send voice notes, while a trip is open. Admins cannot read conversations. Voice files are kept in private storage and deleted after the retention period."));
    var card = h("div", { class: "card" }, h("div", { class: "t", text: "Settings" }));
    root.appendChild(card);
    api("GET", "/admin/chat-settings").then(function (r) {
      var s = (r.body || {}).data || { enabled: true, voice_enabled: true, max_voice_seconds: 60, retention_days: 30 };
      var on = select([["1", "On"], ["0", "Off"]], s.enabled === false ? "0" : "1");
      var vo = select([["1", "On"], ["0", "Off"]], s.voice_enabled === false ? "0" : "1");
      var mx = num(String(s.max_voice_seconds), "60"), rt = num(String(s.retention_days), "30"), out = h("p", { class: "msg" });
      card.appendChild(field("Chat", on, "Off hides the Message button and stops new messages."));
      card.appendChild(field("Voice messages", vo));
      card.appendChild(h("div", { class: "grid2" }, field("Longest voice message (seconds)", mx, "10 to 180."), field("Keep messages for (days)", rt, "1 to 365. Older messages and voice files are deleted.")));
      if (can("ride_chat edit")) {
        var save = h("button", { text: "Save", class: "small", style: "margin-top:10px" });
        save.addEventListener("click", function () {
          save.disabled = true;
          api("PUT", "/admin/chat-settings", { enabled: on.value === "1", voice_enabled: vo.value === "1", max_voice_seconds: nn(mx), retention_days: nn(rt) }).then(function (x) { save.disabled = false; if (x.ok) toast("Saved"); else msg(out, errText(x)); });
        });
        card.appendChild(save);
      } else { on.disabled = true; vo.disabled = true; mx.disabled = true; rt.disabled = true; }
      card.appendChild(out);
    });
  }

  function pageCalls(root) {
    loading(root);
    root.textContent = "";
    root.appendChild(head("Voice calls", "Passengers and their assigned driver can call each other inside the app while a trip is open. Phone numbers are never shown. Calls are not recorded. Keys are saved encrypted and are never shown again."));
    var card = h("div", { class: "card" }, h("div", { class: "t", text: "Settings" }));
    root.appendChild(card);
    api("GET", "/admin/call-settings").then(function (r) {
      var s = (r.body || {}).data || {};
      var on = select([["1", "On"], ["0", "Off"]], s.enabled ? "1" : "0");
      var pref = select([["livekit", "LiveKit"], ["agora", "Agora"]], s.provider || "livekit");
      var ring = num(String(s.ring_seconds || 30), "30"), mx = num(String(s.max_minutes || 60), "60"), out = h("p", { class: "msg" });
      card.appendChild(field("In-app calling", on, "Off hides the call button everywhere. Nothing rings until a provider below is switched on and fully set up."));
      card.appendChild(h("div", { class: "grid2" }, field("Ring for (seconds)", ring, "10 to 60. Then it counts as a missed call."), field("Longest call (minutes)", mx, "5 to 240. Longer calls are ended.")));
      card.appendChild(field("Preferred provider", pref, "If it is off or not set up, the other one is used."));
      var ready = (s.ready || []);
      var lkOn = select([["1", "On"], ["0", "Off"]], s.livekit_enabled ? "1" : "0");
      var lkUrl = text(s.livekit_url || "", "wss://your-project.livekit.cloud"), lkKey = text(s.livekit_api_key || "", "API key");
      var lkSecret = h("input", { type: "password", autocomplete: "off", placeholder: s.livekit_secret_saved ? "Saved. Paste a new secret only to replace it." : "API secret" });
      card.appendChild(h("div", { class: "t", style: "margin-top:14px", text: "LiveKit" + (ready.indexOf("livekit") >= 0 ? "  \u00B7 ready" : "  \u00B7 not ready") }));
      card.appendChild(field("LiveKit", lkOn));
      card.appendChild(field("Server address", lkUrl, "Starts with wss://"));
      card.appendChild(h("div", { class: "grid2" }, field("API key", lkKey), field("API secret", lkSecret)));
      var agOn = select([["1", "On"], ["0", "Off"]], s.agora_enabled ? "1" : "0");
      var agId = text(s.agora_app_id || "", "App ID");
      var agCert = h("input", { type: "password", autocomplete: "off", placeholder: s.agora_certificate_saved ? "Saved. Paste a new certificate only to replace it." : "App certificate" });
      card.appendChild(h("div", { class: "t", style: "margin-top:14px", text: "Agora" + (ready.indexOf("agora") >= 0 ? "  \u00B7 ready" : "  \u00B7 not ready") }));
      card.appendChild(field("Agora", agOn));
      card.appendChild(h("div", { class: "grid2" }, field("App ID", agId), field("App certificate", agCert)));
      if (can("ride_call edit")) {
        var save = h("button", { text: "Save", class: "small", style: "margin-top:10px" });
        save.addEventListener("click", function () {
          save.disabled = true;
          api("PUT", "/admin/call-settings", {
            enabled: on.value === "1", provider: pref.value, livekit_enabled: lkOn.value === "1", agora_enabled: agOn.value === "1",
            ring_seconds: nn(ring), max_minutes: nn(mx), livekit_url: lkUrl.value.trim(), livekit_api_key: lkKey.value.trim(), agora_app_id: agId.value.trim(),
            livekit_api_secret: lkSecret.value.trim(), agora_app_certificate: agCert.value.trim()
          }).then(function (x) { save.disabled = false; if (x.ok) { toast("Saved"); pageCalls(root); } else msg(out, errText(x)); });
        });
        card.appendChild(save);
      } else { [on, pref, ring, mx, lkOn, lkUrl, lkKey, lkSecret, agOn, agId, agCert].forEach(function (e) { e.disabled = true; }); }
      card.appendChild(out);
    });
    var hist = h("div", { class: "card" }, h("div", { class: "t", text: "Recent calls" }));
    root.appendChild(hist);
    api("GET", "/admin/calls").then(function (r) {
      var list = (r.body || {}).data || [];
      if (!list.length) hist.appendChild(h("div", { class: "empty", text: "No calls yet." }));
      list.forEach(function (x) {
        var dur = x.duration_seconds != null ? " \u00B7 " + Math.floor(x.duration_seconds / 60) + "m " + (x.duration_seconds % 60) + "s" : "";
        hist.appendChild(h("div", { class: "row", style: "padding:10px 0;border-top:1px solid var(--line,#eee)" },
          h("div", { class: "t", text: (x.caller || "") + " \u2192 " + (x.callee || "") + " \u00B7 " + x.status + dur }),
          h("div", { class: "s", text: "Trip #" + x.ride_request_id + " \u00B7 " + x.provider + " \u00B7 " + new Date(x.created_at).toLocaleString() + (x.end_reason ? " \u00B7 " + x.end_reason : "") })));
      });
    });
  }

  function pagePickup(root) {
    loading(root);
    root.textContent = "";
    root.appendChild(head("Pickup codes", "The passenger sees a 4-digit code once a driver accepts. The driver must type it before the trip can start, so the right person gets in the right car. Codes are never shown to admins or drivers."));
    var card = h("div", { class: "card" }, h("div", { class: "t", text: "Settings" }));
    root.appendChild(card);
    api("GET", "/admin/pickup-settings").then(function (r) {
      var s = (r.body || {}).data || { enabled: true, expiry_minutes: 180, max_attempts: 5, lock_minutes: 10 };
      var on = select([["1", "On"], ["0", "Off"]], s.enabled === false ? "0" : "1");
      var ex = num(String(s.expiry_minutes), "180"), at = num(String(s.max_attempts), "5"), lk = num(String(s.lock_minutes), "10"), out = h("p", { class: "msg" });
      card.appendChild(field("Require the pickup code", on, "When off, drivers start trips without a code."));
      card.appendChild(h("div", { class: "grid2" }, field("Code valid for (minutes)", ex, "10 to 720."), field("Wrong tries before lock", at, "3 to 10.")));
      card.appendChild(field("Lock time after too many wrong tries (minutes)", lk, "1 to 120. After three locks only an admin can authorise the trip."));
      if (can("pickup_code edit")) {
        var save = h("button", { text: "Save", class: "small", style: "margin-top:10px" });
        save.addEventListener("click", function () {
          save.disabled = true;
          api("PUT", "/admin/pickup-settings", { enabled: on.value === "1", expiry_minutes: nn(ex), max_attempts: nn(at), lock_minutes: nn(lk) }).then(function (x) { save.disabled = false; if (x.ok) toast("Saved"); else msg(out, errText(x)); });
        });
        card.appendChild(save);
      } else { on.disabled = true; ex.disabled = true; at.disabled = true; lk.disabled = true; }
      card.appendChild(out);
    });
    var live = h("div", { class: "card" }, h("div", { class: "t", text: "Rides waiting for pickup" }));
    root.appendChild(live);
    api("GET", "/admin/pickup-rides").then(function (r) {
      var list = (r.body || {}).data || [];
      if (!list.length) live.appendChild(h("div", { class: "empty", text: "No rides are waiting for pickup." }));
      list.forEach(function (x) {
        var state = x.overridden ? "Authorised by admin" : x.verified ? "Code verified" : !x.has_code ? "No code (older ride)" : x.locked ? "Locked after wrong tries" : "Waiting for code" + (x.failed ? " \u00B7 " + x.failed + " wrong" : "");
        var row = h("div", { class: "row", style: "padding:10px 0;border-top:1px solid var(--line,#eee)" },
          h("div", { class: "t", text: "Trip #" + x.id + " \u00B7 " + x.status + " \u00B7 " + state }),
          h("div", { class: "s", text: "Driver: " + (x.driver || "") + " \u00B7 Passenger: " + (x.passenger || "") + (x.booking_source === "admin" ? " \u00B7 booked by admin" : "") }),
          h("div", { class: "s", text: x.pickup || "" }));
        if (x.has_code && !x.verified && !x.overridden && can("pickup_code edit")) {
          var bt = h("button", { text: "Authorise start without code", class: "small secondary", style: "margin-top:8px" });
          bt.addEventListener("click", function () {
            confirmDo("Let the driver start trip #" + x.id + " without the pickup code? Use this only if you have confirmed the passenger by other means. This is recorded.", function () {
              api("POST", "/admin/pickup-rides/" + x.id + "/override", {}).then(function (z) { toast(z.ok ? z.body.message : errText(z), !z.ok); if (z.ok) pagePickup(root); });
            });
          });
          row.appendChild(bt);
        }
        live.appendChild(row);
      });
    });
  }

  var ex = { status: "paid", page: 1 };
  function pageExtras(root) {
    loading(root);
    api("GET", "/admin/extras?status=" + ex.status + "&page=" + ex.page).then(function (r) {
      var b = r.body || {}, list = b.data || [], pg = b.pagination || { page: 1, total_pages: 1, total: 0 };
      root.textContent = "";
      root.appendChild(head("Extra charges", "Tolls, parking and waiting charges that drivers add after accepting a ride. Refund a paid one if there is a dispute: wallet money goes back to the passenger and is taken from the driver."));
      var top = h("div"); root.appendChild(top); extrasCard(top); extraTypesCard(top);
      var tabs = h("div", { style: "display:flex;gap:8px;margin:12px 0;flex-wrap:wrap" });
      [["paid", "Paid"], ["pending", "Waiting"], ["declined", "Declined"], ["expired", "Expired"], ["cancelled", "Cancelled / refunded"]].forEach(function (t) {
        var bt = h("button", { text: t[1], class: "small" + (ex.status === t[0] ? "" : " secondary") });
        bt.addEventListener("click", function () { ex.status = t[0]; ex.page = 1; pageExtras(root); });
        tabs.appendChild(bt);
      });
      root.appendChild(tabs);
      var card = h("div", { class: "card" }, h("div", { class: "t", text: pg.total + " extra charge" + (pg.total === 1 ? "" : "s") }));
      if (!list.length) card.appendChild(h("div", { class: "empty", text: "Nothing here." }));
      list.forEach(function (x) {
        var sym = (x.currency && x.currency.symbol) || "\u20A6";
        var row = h("div", { class: "row", style: "padding:10px 0;border-top:1px solid var(--line,#eee)" },
          h("div", { class: "t", text: "#" + x.id + " \u00B7 " + x.kind + " \u00B7 " + sym + Number(x.amount).toLocaleString() + (x.paid_with ? " \u00B7 " + x.paid_with : "") }),
          h("div", { class: "s", text: "Trip #" + x.ride_id + " \u00B7 Driver: " + (x.driver_name || "") + " \u00B7 Passenger: " + (x.passenger_name || "") }),
          h("div", { class: "s", text: String(x.created_at).slice(0, 16).replace("T", " ") + " UTC" + (x.note ? " \u00B7 " + x.note : "") }));
        if ((x.status === "paid" || x.status === "pending") && can("ride_extra edit")) {
          var bt = h("button", { text: x.status === "paid" ? "Refund" : "Cancel", class: "small secondary", style: "margin-top:8px" });
          bt.addEventListener("click", function () {
            confirmDo((x.status === "paid" ? "Refund this extra charge? " + (x.paid_with === "wallet" ? "The passenger's wallet is credited and the driver's wallet is debited." : "It was a cash extra, so no wallet money moves.") : "Cancel this extra charge?"), function () {
              api("POST", "/admin/extras/" + x.id + "/refund", {}).then(function (z) { toast(z.ok ? z.body.message : errText(z), !z.ok); if (z.ok) pageExtras(root); });
            });
          });
          row.appendChild(bt);
        }
        card.appendChild(row);
      });
      root.appendChild(card);
      if (pg.total_pages > 1) {
        var nav = h("div", { style: "display:flex;gap:8px;margin-top:12px" });
        var prev = h("button", { text: "Previous", class: "small secondary" }), next = h("button", { text: "Next", class: "small secondary" });
        prev.disabled = pg.page <= 1; next.disabled = pg.page >= pg.total_pages;
        prev.addEventListener("click", function () { ex.page--; pageExtras(root); });
        next.addEventListener("click", function () { ex.page++; pageExtras(root); });
        nav.appendChild(prev); nav.appendChild(next); root.appendChild(nav);
      }
    });
  }

  var so = { status: "open", page: 1 };
  function pageSos(root) {
    loading(root);
    api("GET", "/admin/sos?status=" + so.status + "&page=" + so.page).then(function (r) {
      var b = r.body || {}, list = b.data || [], pg = b.pagination || { page: 1, total_pages: 1, total: 0 };
      root.textContent = "";
      root.appendChild(head("SOS alerts", "When a rider or driver presses SOS, it appears here with their location, phone and trip. Call them, then mark it acknowledged and finally resolved. This page refreshes itself every 20 seconds."));
      if (can("sos edit")) {
        var em = text((b.settings || {}).notify_emails, "e.g. ops@yourdomain.com, safety@yourdomain.com"), out = h("p", { class: "msg" });
        var sv = h("button", { text: "Save", class: "small", style: "margin-top:10px" });
        sv.addEventListener("click", function () {
          sv.disabled = true;
          api("PUT", "/admin/sos/settings", { notify_emails: em.value }).then(function (x) { sv.disabled = false; if (x.ok) toast("Saved"); else msg(out, errText(x)); });
        });
        root.appendChild(h("div", { class: "card" }, field("Email me when someone presses SOS", em, "Separate several with commas. Left empty, every active admin is emailed. Needs the Resend keys under Payment methods; the alert always shows here either way."), sv, out));
      }
      var tabs = h("div", { style: "display:flex;gap:8px;margin:12px 0" });
      [["open", "Open"], ["acknowledged", "Acknowledged"], ["resolved", "Resolved"]].forEach(function (t) {
        var bt = h("button", { text: t[1], class: "small" + (so.status === t[0] ? "" : " secondary") });
        bt.addEventListener("click", function () { so.status = t[0]; so.page = 1; pageSos(root); });
        tabs.appendChild(bt);
      });
      root.appendChild(tabs);
      var card = h("div", { class: "card" }, h("div", { class: "t", text: pg.total + " alert" + (pg.total === 1 ? "" : "s") }));
      if (!list.length) card.appendChild(h("div", { class: "empty", text: "Nothing here." }));
      list.forEach(function (a) {
        var c = a.context || {}, who = c.person || {}, other = c.other_party, ride = c.ride, veh = c.vehicle;
        var row = h("div", { class: "row", style: "padding:10px 0;border-top:1px solid var(--line,#eee)" },
          h("div", { class: "t", text: "#" + a.id + " · " + (who.name || "Unknown") + " (" + a.role + ") · " + (who.phone || "no phone") }),
          h("div", { class: "s", text: String(a.created_at).slice(0, 16).replace("T", " ") + " UTC" }));
        if (ride) row.appendChild(h("div", { class: "s", text: "Trip #" + ride.id + " (" + ride.status + "): " + ride.pickup + " → " + ride.dropoff }));
        if (other) row.appendChild(h("div", { class: "s", text: (a.role === "driver" ? "Passenger: " : "Driver: ") + (other.name || "") + " " + (other.phone || "") }));
        if (veh) row.appendChild(h("div", { class: "s", text: "Vehicle: " + (veh.description || "") + " " + (veh.plate || "") }));
        if (a.message) row.appendChild(h("div", { class: "s", text: "Message: " + a.message }));
        if (a.admin_note) row.appendChild(h("div", { class: "s", text: "Note: " + a.admin_note }));
        if (a.latitude != null && a.longitude != null) {
          var map = h("a", { href: "https://www.google.com/maps?q=" + a.latitude + "," + a.longitude, target: "_blank", rel: "noopener", text: "Open location on the map" });
          row.appendChild(h("div", { class: "s" }, map));
        } else row.appendChild(h("div", { class: "s", text: "No location was shared." }));
        if (a.status !== "resolved" && can("sos edit")) {
          if (a.status === "open") {
            var ack = h("button", { text: "Acknowledge", class: "small", style: "margin-top:8px" });
            ack.addEventListener("click", function () { api("PUT", "/admin/sos/" + a.id, { status: "acknowledged" }).then(function (x) { toast(x.ok ? x.body.message : errText(x), !x.ok); if (x.ok) { pageSos(root); sosBadge(); } }); });
            row.appendChild(ack);
          }
          var res = h("button", { text: "Mark resolved", class: "small secondary", style: "margin:8px 0 0 8px" });
          res.addEventListener("click", function () {
            var note = window.prompt("Add a short note about what happened (optional).") || "";
            api("PUT", "/admin/sos/" + a.id, { status: "resolved", note: note }).then(function (x) { toast(x.ok ? x.body.message : errText(x), !x.ok); if (x.ok) { pageSos(root); sosBadge(); } });
          });
          row.appendChild(res);
        }
        card.appendChild(row);
      });
      root.appendChild(card);
      // Keep the open alerts fresh while this page is on screen.
      clearTimeout(pageSos.timer);
      pageSos.timer = setTimeout(function () { if (location.hash.indexOf("#/sos") === 0 && root.isConnected) pageSos(root); }, 20000);
    });
  }

  // A red bar at the top of every admin page while an SOS alert is open.
  function sosBadge() {
    if (!can("sos list")) return;
    api("GET", "/admin/sos/open-count").then(function (r) {
      var n = r.ok ? (r.body || {}).open : 0, bar = $("sosBar");
      if (!bar) {
        bar = h("a", { id: "sosBar", href: "#/sos", style: "display:none;background:#c62828;color:#fff;padding:10px 16px;font-weight:700;text-align:center;text-decoration:none" });
        var app = $("app"); app.insertBefore(bar, app.firstChild);
      }
      bar.style.display = n > 0 ? "block" : "none";
      bar.textContent = n > 0 ? "⚠ " + n + " open SOS alert" + (n === 1 ? "" : "s") + " — tap to handle" : "";
      document.title = (n > 0 ? "(" + n + ") " : "") + ($("title").textContent || "Admin");
    });
  }

  var cm = { status: "pending", page: 1, open: null };
  function pageComplaints(root) {
    loading(root);
    api("GET", "/admin/complaints?status=" + cm.status + "&page=" + cm.page).then(function (r) {
      var b = r.body || {}, list = b.data || [], pg = b.pagination || { page: 1, total_pages: 1, total: 0 };
      root.textContent = "";
      root.appendChild(head("Complaints", "What riders and drivers report. Reply to them here (they see your reply in the app under Help & complaints) and move the complaint along."));
      var tabs = h("div", { style: "display:flex;gap:8px;margin:12px 0" });
      [["pending", "New"], ["investigating", "Being looked into"], ["resolved", "Resolved"]].forEach(function (t) {
        var bt = h("button", { text: t[1], class: "small" + (cm.status === t[0] ? "" : " secondary") });
        bt.addEventListener("click", function () { cm.status = t[0]; cm.page = 1; cm.open = null; pageComplaints(root); });
        tabs.appendChild(bt);
      });
      root.appendChild(tabs);
      var card = h("div", { class: "card" }, h("div", { class: "t", text: pg.total + " complaint" + (pg.total === 1 ? "" : "s") }));
      if (!list.length) card.appendChild(h("div", { class: "empty", text: "Nothing here." }));
      list.forEach(function (c) {
        var row = h("div", { class: "row", style: "padding:10px 0;border-top:1px solid var(--line,#eee);cursor:pointer" },
          h("div", { class: "t", text: "#" + c.id + " · " + c.subject }),
          h("div", { class: "s", text: c.person + " (" + c.role + ") · " + String(c.created_at).slice(0, 16).replace("T", " ") + (c.ride_request_id ? " · trip #" + c.ride_request_id : "") }));
        row.addEventListener("click", function () { cm.open = cm.open === c.id ? null : c.id; pageComplaints(root); });
        card.appendChild(row);
        if (cm.open === c.id) {
          var box = h("div", { style: "padding:6px 0 12px" }, h("div", { class: "s", text: "Loading…" }));
          card.appendChild(box);
          api("GET", "/admin/complaints/" + c.id).then(function (x) {
            var d = (x.body || {}).data; if (!d) { box.textContent = errText(x); return; }
            box.textContent = "";
            box.appendChild(h("div", { class: "s", text: d.person + " · " + (d.phone || "no phone") }));
            box.appendChild(h("p", { text: d.description, style: "white-space:pre-wrap" }));
            (d.comments || []).forEach(function (m) {
              box.appendChild(h("div", { class: "s", style: "margin:4px 0;white-space:pre-wrap", text: (m.added_by === "admin" ? "You: " : "Them: ") + m.comment + "  (" + String(m.created_at).slice(0, 16).replace("T", " ") + ")" }));
            });
            if (can("complaint edit")) {
              var reply = h("textarea", { rows: "3", placeholder: "Write a reply the person will see in their app", style: "width:100%;margin-top:8px" });
              var st = select([["", "Keep status"], ["pending", "New"], ["investigating", "Being looked into"], ["resolved", "Resolved"]], "");
              var send = h("button", { text: "Save", class: "small", style: "margin-top:8px" }), o2 = h("p", { class: "msg" });
              send.addEventListener("click", function () {
                send.disabled = true;
                api("PUT", "/admin/complaints/" + c.id, { comment: reply.value, status: st.value || undefined }).then(function (y) { send.disabled = false; if (y.ok) { toast("Saved"); pageComplaints(root); } else msg(o2, errText(y)); });
              });
              box.appendChild(reply); box.appendChild(field("Status", st)); box.appendChild(send); box.appendChild(o2);
            }
          });
        }
      });
      root.appendChild(card);
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
            h("div", { class: "s", text: [a.ride_type, a.region ? "Region: " + a.region : null, vehicle].filter(Boolean).join(" · ") || "No vehicle yet" }),
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
        ["Ride type", d.ride_type], ["Region", d.region], ["Date of birth", d.date_of_birth ? String(d.date_of_birth).slice(0, 10) : null], ["Years driving", d.licence_years],
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
        var locked = ["approved", "suspended", "in_review", "submitted"].indexOf(d.status) >= 0;
        if (canEdit && locked) {
          if (x.requested) acts.appendChild(h("button", { class: "ghost small", text: "Withdraw request", on: { click: function () {
            api("DELETE", "/admin/driver-applications/" + id + "/request-documents/" + x.document_id).then(function (z) { toast(z.ok ? "Request withdrawn" : errText(z), !z.ok); if (z.ok) applicationDetail(root, id); });
          } } }));
          else acts.appendChild(h("button", { class: "ghost small", text: x.uploaded ? "Ask for new upload" : "Request upload", on: { click: function () {
            var note = window.prompt("Message for the driver (optional):", x.status === "rejected" && x.note ? x.note : "");
            if (note === null) return;
            api("POST", "/admin/driver-applications/" + id + "/request-documents", { document_ids: [x.document_id], note: note.trim() || undefined }).then(function (z) { toast(z.ok ? "Driver asked to upload " + x.name : errText(z), !z.ok); if (z.ok) applicationDetail(root, id); });
          } } }));
        }
        if (x.uploaded && canEdit && (reviewable || d.status === "approved" || d.status === "suspended")) {
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
            x.requested ? h("div", { class: "s", text: "Waiting for the driver to upload" + (x.request_note ? " · Your message: " + x.request_note : "") }) : null,
            h("div", { style: "margin-top:8px" }, acts), view),
          h("span", { class: "pill " + (x.requested ? "warn" : pillFor(x.status)), text: x.requested ? "Requested" : (DOC_STATUS[x.status] || x.status) })));
      });
      root.appendChild(docs);

      if (canEdit && ["approved", "suspended", "in_review", "submitted"].indexOf(d.status) >= 0) {
        var missingDocs = d.documents.filter(function (x) { return x.required && (!x.uploaded || x.status === "rejected") && !x.requested; });
        if (missingDocs.length) {
          var reqOut = h("p", { class: "msg" });
          root.appendChild(h("div", { class: "card" }, h("h3", { text: "Missing documents" }),
            h("p", { class: "s", text: missingDocs.map(function (x) { return x.name; }).join(", ") + " — the driver stays " + (APP_STATUS[d.status] || d.status).toLowerCase() + " and can upload only what you ask for." }),
            reqOut,
            h("button", { class: "small", text: "Request " + missingDocs.length + " document" + (missingDocs.length === 1 ? "" : "s"), on: { click: function (e) {
              var note = window.prompt("Message for the driver (optional):", "Please upload your missing documents so we can keep your account in good standing.");
              if (note === null) return;
              e.target.disabled = true;
              api("POST", "/admin/driver-applications/" + id + "/request-documents", { note: note.trim() || undefined }).then(function (z) {
                if (z.ok) { toast(z.body.message); applicationDetail(root, id); } else { e.target.disabled = false; msg(reqOut, errText(z)); }
              });
            } } })));
        }
      }

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


  // ---------- Admin-initiated ride booking ----------
  function pageOrderRide(root) {
    root.textContent = "";
    root.classList.add("order-ride");
    var state = { passenger: null, pickup: null, dropoff: null, quote: null, service: null, options: [], payment: "cash" };
    var searchUsers = text("", "Search by name, username, phone or email");
    var userResults = h("div");
    var pickupInput = text("", "Search pickup address");
    var dropInput = text("", "Search destination address");
    var pickupResults = h("div"), dropResults = h("div");
    var pickupSelected = h("div", { class: "hint" }), dropSelected = h("div", { class: "hint" });
    var quoteBox = h("div"), resultBox = h("div"), historyBox = h("div");
    var userSearchBtn = h("button", { text: "Search passenger", class: "small" });
    var quoteBtn = h("button", { text: "Calculate fare estimate", class: "small", disabled: true });
    var out = h("p", { class: "msg" });
    var selectedFare = h("div", { class: "t" });
    root.appendChild(head("Order Ride", "Book a genuine Drop ride for an existing passenger. The passenger remains the ride owner."));
    root.appendChild(h("div", { class: "card" },
      h("h3", { text: "1. Select passenger" }),
      field("Find an existing passenger", searchUsers),
      userSearchBtn, userResults));
    function userSearch() {
      var q = searchUsers.value.trim();
      if (q.length < 2) { toast("Enter at least 2 characters.", true); return; }
      userSearchBtn.disabled = true;
      api("GET", "/admin/order-ride/users?q=" + encodeURIComponent(q)).then(function (r) {
        userSearchBtn.disabled = false; userResults.textContent = "";
        var list = (r.body && r.body.data) || [];
        if (!r.ok) { userResults.appendChild(h("p", { class: "msg err", text: errText(r) })); return; }
        if (!list.length) { userResults.appendChild(h("p", { class: "empty", text: "No matching registered passenger found." })); return; }
        list.forEach(function (u) {
          var active = u.status === "active" && u.active_mode === "rider" && (u.user_type === "rider" || u.user_type === "driver");
          var detail = [u.username ? "@" + u.username : "", (u.country_code || "") + (u.contact_number || ""), u.email || "", u.status, u.active_mode === "rider" ? "Passenger mode" : "Not in Passenger mode"].filter(Boolean).join(" · ");
          var b = h("button", { class: "ghost small", text: active ? "Select" : "Unavailable", disabled: !active });
          b.addEventListener("click", function () {
            state.passenger = u; userResults.textContent = "";
            userResults.appendChild(h("div", { class: "or-selected" },
              h("div", { class: "t", text: u.display_name || u.username || ("User #" + u.id) }),
              h("div", { class: "s", text: detail + " · ID " + u.id }),
              h("button", { class: "ghost small", text: "Change passenger", on: { click: function () { state.passenger = null; pageOrderRide(root); } } })));
            updateQuoteButton();
          });
          userResults.appendChild(h("div", { class: "item" },
            h("div", { class: "main" }, h("div", { class: "t", text: (u.display_name || u.username || "User") + " · " + u.user_type }), h("div", { class: "s", text: detail })),
            b));
        });
      });
    }
    userSearchBtn.addEventListener("click", userSearch);
    searchUsers.addEventListener("keydown", function (e) { if (e.key === "Enter") userSearch(); });

    var locationCard = h("div", { class: "card" },
      h("h3", { text: "2. Pickup and destination" }),
      field("Pickup", pickupInput), pickupResults, pickupSelected,
      field("Destination", dropInput), dropResults, dropSelected);
    function updateQuoteButton() { quoteBtn.disabled = !(state.passenger && state.pickup && state.dropoff); }
    function placeSearch(input, target, which) {
      var q = input.value.trim();
      if (q.length < 2) { toast("Enter at least 2 characters for the location.", true); return; }
      target.textContent = ""; target.appendChild(h("p", { class: "muted", text: "Searching locations…" }));
      api("GET", "/places/search?q=" + encodeURIComponent(q)).then(function (r) {
        target.textContent = "";
        var hits = (r.body && r.body.data) || [];
        if (!r.ok || !hits.length) { target.appendChild(h("p", { class: "empty", text: r.ok ? "No location results. Try a more specific search." : errText(r) })); return; }
        hits.forEach(function (hit) {
          target.appendChild(h("button", { class: "ghost or-place", type: "button",
            on: { click: function () {
              state[which] = { lat: Number(hit.lat), lng: Number(hit.lng), address: [hit.title, hit.subtitle].filter(Boolean).join(", ") };
              input.value = state[which].address;
              target.textContent = "";
              var dest = which === "pickup" ? pickupSelected : dropSelected;
              dest.textContent = "Selected: " + state[which].address + " · " + state[which].lat.toFixed(6) + ", " + state[which].lng.toFixed(6);
              updateQuoteButton(); quoteBox.textContent = ""; resultBox.textContent = ""; state.quote = null;
            } } }, h("span", { class: "t", text: hit.title }), h("span", { class: "s", text: hit.subtitle || (hit.lat + ", " + hit.lng) })));
        });
      });
    }
    var pickupSearchBtn = h("button", { class: "ghost small", text: "Search pickup" });
    var dropSearchBtn = h("button", { class: "ghost small", text: "Search destination" });
    pickupSearchBtn.addEventListener("click", function () { placeSearch(pickupInput, pickupResults, "pickup"); });
    dropSearchBtn.addEventListener("click", function () { placeSearch(dropInput, dropResults, "dropoff"); });
    pickupInput.addEventListener("keydown", function (e) { if (e.key === "Enter") placeSearch(pickupInput, pickupResults, "pickup"); });
    dropInput.addEventListener("keydown", function (e) { if (e.key === "Enter") placeSearch(dropInput, dropResults, "dropoff"); });
    locationCard.appendChild(h("div", { class: "row" }, pickupSearchBtn, dropSearchBtn));
    root.appendChild(locationCard);

    quoteBtn.addEventListener("click", function () {
      quoteBtn.disabled = true; msg(out, "Calculating server-side fare estimate…");
      api("POST", "/admin/order-ride/estimate", { pickup: state.pickup, dropoff: state.dropoff }).then(function (r) {
        quoteBtn.disabled = false; quoteBox.textContent = ""; resultBox.textContent = ""; state.quote = null;
        if (!r.ok) { msg(out, errText(r)); return; }
        state.quote = r.body; state.service = null; state.options = [];
        msg(out, "Fare estimate ready.", true);
        var types = r.body.ride_types || [];
        if (!types.length) { quoteBox.appendChild(h("p", { class: "empty", text: "No ride types are currently available for this route." })); return; }
        var typeSelect = select(types.map(function (t) { return [t.id, t.name + " · " + naira(t.fare) + " · " + t.drivers_nearby + " nearby drivers"]; }), types[0].id);
        state.service = types[0];
        typeSelect.addEventListener("change", function () { state.service = types.filter(function (t) { return String(t.id) === typeSelect.value; })[0] || null; state.options = []; renderQuoteOptions(); });
        var optionBox = h("div"), payment = select([], "");
        function renderQuoteOptions() {
          optionBox.textContent = ""; payment.textContent = "";
          var t = state.service; if (!t) return;
          state.options = [];
          (r.body.options || []).forEach(function (o) {
            var cb = h("input", { type: "checkbox" });
            cb.addEventListener("change", function () { if (cb.checked) state.options.push(o.id); else state.options = state.options.filter(function (id) { return id !== o.id; }); updateEstimateTotal(); });
            optionBox.appendChild(h("label", { class: "or-option" }, cb, h("span", { text: o.name + " · " + naira(o.price) })));
          });
          payment = select((t.payment_methods || []).map(function (m) { return [m, m.replace(/_/g, " ").replace(/^./, function (x) { return x.toUpperCase(); })]; }), (t.payment_methods || [])[0]);
          payment.addEventListener("change", function () { state.payment = payment.value; });
          state.payment = payment.value;
          updateEstimateTotal();
          resultBox.textContent = "";
          resultBox.appendChild(h("div", { class: "card" },
            h("h3", { text: "3. Ride configuration" }),
            field("Ride type", typeSelect),
            field("Optional extras", optionBox),
            field("Payment method", payment),
            h("p", { class: "muted", text: "Only ride types and payment methods currently enabled for this route are shown. Scheduled booking is not offered here because the current booking API supports immediate requests only." }),
            selectedFare,
            h("button", { text: "Review and confirm booking", on: { click: confirmBooking } })));
        }
        function updateEstimateTotal() {
          var extra = (r.body.options || []).filter(function (o) { return state.options.indexOf(o.id) >= 0; }).reduce(function (a, o) { return a + Number(o.price); }, 0);
          selectedFare.textContent = "Estimated total: " + naira(Number(state.service.fare) + extra) + " · " + Number(r.body.distance).toFixed(1) + " " + r.body.distance_unit + " · " + Math.round(r.body.duration_minutes) + " min";
        }
        renderQuoteOptions();
      });
    });
    root.appendChild(h("div", { class: "card" }, h("h3", { text: "Fare estimate" }), quoteBtn, out, quoteBox, resultBox));

    function confirmBooking() {
      if (!state.passenger || !state.pickup || !state.dropoff || !state.service || !state.quote) return;
      var summary = [
        "Passenger: " + (state.passenger.display_name || state.passenger.username),
        "Pickup: " + state.pickup.address, "Destination: " + state.dropoff.address,
        "Ride: " + state.service.name, "Payment: " + state.payment,
        "Estimated fare: " + selectedFare.textContent
      ].join("\n");
      if (!window.confirm("Confirm this Admin-initiated booking?\n\n" + summary)) return;
      var key = (window.crypto && crypto.randomUUID) ? crypto.randomUUID() : "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g, function (c) { var r = Math.random() * 16 | 0; return (c === "x" ? r : (r & 3 | 8)).toString(16); });
      var button = resultBox.querySelector("button"); if (button) button.disabled = true;
      api("POST", "/admin/order-ride", {
        passenger_id: state.passenger.id, pickup: state.pickup, dropoff: state.dropoff,
        service_id: state.service.id, payment_method: state.payment, option_ids: state.options, idempotency_key: key
      }).then(function (r) {
        if (button) button.disabled = false;
        if (!r.ok) { toast(errText(r), true); return; }
        var ride = r.body.data || {};
        resultBox.textContent = "";
        resultBox.appendChild(h("div", { class: "card" },
          h("div", { class: "pill on", text: "Ride request created" }),
          h("h3", { text: "Ride #" + ride.id }),
          h("p", { class: "muted", text: "Status: " + ride.status + " · Passenger: " + (ride.passenger && ride.passenger.name || "") }),
          h("p", { text: "The passenger has been notified where push notifications are configured. Nearby eligible drivers have been notified through the existing dispatch flow." }),
          h("button", { class: "ghost small", text: "View booking history", on: { click: function () { loadHistory(); historyBox.scrollIntoView({ behavior: "smooth" }); } } })));
        toast("Ride request created");
        loadHistory();
      });
    }

    var historyQuery = text("", "Search by ride ID or passenger");
    var historyStatus = select([["", "All statuses"], ["searching", "Searching"], ["accepted", "Driver assigned"], ["arrived", "Driver arrived"], ["in_progress", "In progress"], ["completed", "Completed"], ["cancelled", "Cancelled"], ["expired", "Expired"]], "");
    function loadHistory() {
      historyBox.textContent = ""; historyBox.appendChild(h("p", { class: "muted", text: "Loading Admin bookings…" }));
      var qs = "?q=" + encodeURIComponent(historyQuery.value.trim()) + "&status=" + encodeURIComponent(historyStatus.value);
      api("GET", "/admin/order-rides" + qs).then(function (r) {
        historyBox.textContent = "";
        if (!r.ok) { historyBox.appendChild(h("p", { class: "msg err", text: errText(r) })); return; }
        var list = (r.body && r.body.data) || [];
        if (!list.length) { historyBox.appendChild(h("div", { class: "empty", text: "No matching Admin-created rides." })); return; }
        list.forEach(function (ride) {
          var status = String(ride.status || "").replace(/_/g, " ");
          var card = h("div", { class: "item or-history" },
            h("div", { class: "main" },
              h("div", { class: "t", text: "Ride #" + ride.id + " · " + status }),
              h("div", { class: "s", text: (ride.passenger && ride.passenger.name || "Passenger") + " · " + (ride.passenger && ride.passenger.phone || "") + " · " + (ride.service && ride.service.name || "") }),
              h("div", { class: "s", text: (ride.pickup && ride.pickup.address || "") + " → " + (ride.dropoff && ride.dropoff.address || "") }),
              h("div", { class: "s", text: naira(ride.fare) + " " + (ride.currency || "") + " · " + ride.payment_method + " · " + (ride.driver && ride.driver.name || "Awaiting driver") + " · Booked by " + (ride.admin && ride.admin.name || "Admin") + " · " + new Date(ride.created_at).toLocaleString() })));
          if (["searching", "accepted", "arrived"].indexOf(ride.status) >= 0 && can("ride_order edit")) {
            card.appendChild(h("button", { class: "danger small", text: "Cancel", on: { click: function () {
              var reason = window.prompt("Why is this Admin booking being cancelled?");
              if (!reason || reason.trim().length < 3) return;
              api("POST", "/admin/order-rides/" + ride.id + "/cancel", { reason: reason.trim() }).then(function (x) { toast(x.ok ? "Ride cancelled" : errText(x), !x.ok); loadHistory(); });
            } } }));
          }
          historyBox.appendChild(card);
        });
      });
    }
    var historySearch = h("button", { class: "small", text: "Search", on: { click: loadHistory } });
    historyQuery.addEventListener("keydown", function (e) { if (e.key === "Enter") loadHistory(); });
    historyStatus.addEventListener("change", loadHistory);
    root.appendChild(h("div", { class: "card" },
      head("Admin booking history", "Recent rides booked on behalf of Drop passengers.", h("button", { class: "ghost small", text: "Refresh", on: { click: loadHistory } })),
      h("div", { class: "grid2" }, field("Search", historyQuery), field("Status", historyStatus)),
      historySearch, historyBox));
    loadHistory();
  }

  // ---------- boot ----------
  if (location.hash === "#setup") showAuth("setup");
  else if (TOKEN) start();
  else showAuth("login");
})();
