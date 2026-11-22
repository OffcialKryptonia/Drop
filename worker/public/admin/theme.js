/* Drop Admin theme: Light / Dark / System. Loaded in <head> so the right theme is applied before first paint.
   The choice is kept in localStorage ("drop_admin_theme"); storage can be blocked, so every access is guarded. */
(function (root, factory) {
  var api = factory(root);
  if (typeof module === "object" && module.exports) module.exports = api;
  else root.DropTheme = api;
})(typeof window !== "undefined" ? window : globalThis, function (win) {
  var KEY = "drop_admin_theme";
  var PREFS = ["light", "dark", "system"];

  function normalize(v) { return PREFS.indexOf(v) >= 0 ? v : "system"; }
  function resolve(pref, systemDark) { pref = normalize(pref); return pref === "system" ? (systemDark ? "dark" : "light") : pref; }

  function read() { try { return normalize(win.localStorage.getItem(KEY)); } catch (e) { return "system"; } }
  function write(pref) { try { win.localStorage.setItem(KEY, normalize(pref)); } catch (e) { /* private mode: keep for this page only */ } }
  function systemDark() { try { return !!(win.matchMedia && win.matchMedia("(prefers-color-scheme: dark)").matches); } catch (e) { return false; } }

  var current = "system";

  function apply(pref, animate) {
    current = normalize(pref);
    var theme = resolve(current, systemDark());
    var el = win.document && win.document.documentElement;
    if (!el) return theme;
    if (animate) {
      el.classList.add("theme-anim");
      win.setTimeout(function () { el.classList.remove("theme-anim"); }, 350);
    }
    el.setAttribute("data-theme", theme);
    el.setAttribute("data-theme-pref", current);
    var meta = win.document.querySelector('meta[name="theme-color"]');
    if (meta) meta.setAttribute("content", theme === "dark" ? "#111111" : "#f4f5f7");
    syncButtons();
    return theme;
  }

  function set(pref) { write(pref); return apply(pref, true); }

  var SUN = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><circle cx="12" cy="12" r="4.2" fill="currentColor" stroke="none"/><g class="sun-rays"><path d="M12 2.5v2.2M12 19.3v2.2M2.5 12h2.2M19.3 12h2.2M5.3 5.3l1.6 1.6M17.1 17.1l1.6 1.6M5.3 18.7l1.6-1.6M17.1 6.9l1.6-1.6"/></g></svg>';
  var MOON = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path class="moon-body" d="M20.2 14.6A8.4 8.4 0 0 1 9.4 3.8a8.4 8.4 0 1 0 10.8 10.8z" fill="currentColor"/></svg>';
  var AUTO = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect x="3" y="4" width="18" height="12" rx="2"/><path d="M8 20h8M12 16v4"/></svg>';
  var CHOICES = [["light", "Light", SUN], ["dark", "Dark", MOON], ["system", "System default", AUTO]];

  function syncButtons() {
    if (!win.document) return;
    var btns = win.document.querySelectorAll(".theme-toggle button");
    for (var i = 0; i < btns.length; i++) btns[i].setAttribute("aria-pressed", btns[i].getAttribute("data-pref") === current ? "true" : "false");
  }

  function mount(slot) {
    var box = win.document.createElement("div");
    box.className = "theme-toggle";
    box.setAttribute("role", "group");
    box.setAttribute("aria-label", "Colour theme");
    CHOICES.forEach(function (c) {
      var b = win.document.createElement("button");
      b.type = "button"; b.className = "ghost"; b.setAttribute("data-pref", c[0]);
      b.setAttribute("aria-label", c[1]); b.title = c[1]; b.innerHTML = c[2];
      b.addEventListener("click", function () { set(c[0]); });
      box.appendChild(b);
    });
    slot.appendChild(box);
    syncButtons();
  }

  function mountAll() {
    var slots = win.document.querySelectorAll(".theme-slot");
    for (var i = 0; i < slots.length; i++) if (!slots[i].firstChild) mount(slots[i]);
  }

  function init() {
    apply(read(), false);
    try {
      var mq = win.matchMedia("(prefers-color-scheme: dark)");
      var onChange = function () { if (current === "system") apply("system", true); };
      if (mq.addEventListener) mq.addEventListener("change", onChange); else if (mq.addListener) mq.addListener(onChange);
    } catch (e) { /* no matchMedia */ }
    if (win.document && win.document.addEventListener) win.document.addEventListener("DOMContentLoaded", mountAll);
  }

  if (win.document && win.document.documentElement) init();
  return { KEY: KEY, PREFS: PREFS, normalize: normalize, resolve: resolve, read: read, write: write, apply: apply, set: set, mountAll: mountAll, CHOICES: CHOICES };
});
