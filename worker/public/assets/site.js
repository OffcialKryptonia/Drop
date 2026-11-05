// DROP website: mobile menu, active nav link, logo reveal. No dependencies.
(function () {
  var root = document.body;
  var toggle = document.querySelector(".nav-toggle");
  var menu = document.getElementById("menu");

  function setMenu(open) {
    root.classList.toggle("nav-open", open);
    toggle.setAttribute("aria-expanded", String(open));
    toggle.firstElementChild.textContent = open ? "Close" : "Menu";
  }
  if (toggle && menu) {
    toggle.addEventListener("click", function () { setMenu(!root.classList.contains("nav-open")); });
    menu.addEventListener("click", function (e) { if (e.target.closest("a")) setMenu(false); });
    document.addEventListener("keydown", function (e) {
      if (e.key === "Escape" && root.classList.contains("nav-open")) { setMenu(false); toggle.focus(); }
    });
    window.matchMedia("(min-width: 64em)").addEventListener("change", function (m) { if (m.matches) setMenu(false); });
  }

  // Mark the current section in the desktop nav.
  var links = [].slice.call(document.querySelectorAll(".nav-links a[href^='#']"));
  if ("IntersectionObserver" in window && links.length) {
    var byId = {};
    links.forEach(function (a) { byId[a.getAttribute("href").slice(1)] = a; });
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (en) {
        if (!en.isIntersecting) return;
        links.forEach(function (a) { a.removeAttribute("aria-current"); });
        var a = byId[en.target.id]; if (a) a.setAttribute("aria-current", "true");
      });
    }, { rootMargin: "-45% 0px -50% 0px" });
    Object.keys(byId).forEach(function (id) { var s = document.getElementById(id); if (s) io.observe(s); });
  }

  // Play the logo reveal once, when it scrolls into view. Skipped for reduced motion (poster shows the final frame).
  var v = document.getElementById("reveal");
  var calm = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  if (v && !calm && "IntersectionObserver" in window) {
    var vio = new IntersectionObserver(function (entries) {
      if (entries[0].isIntersecting) { var p = v.play(); if (p && p.catch) p.catch(function () {}); vio.disconnect(); }
    }, { threshold: 0.6 });
    vio.observe(v);
  }

  var y = document.getElementById("year"); if (y) y.textContent = new Date().getFullYear();
})();
