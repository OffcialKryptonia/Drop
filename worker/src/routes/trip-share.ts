import { Hono } from "hono";
import type { AppEnv } from "../env";
import { withDb } from "../db";
import { requireAuth } from "../auth/middleware";
import { mapSettings } from "../lib/maps";

export const tripShareRoutes = new Hono<AppEnv>();

/** 32 random bytes as url-safe text: impossible to guess, safe to put in a link. */
const newToken = () => {
  const b = crypto.getRandomValues(new Uint8Array(24));
  return btoa(String.fromCharCode(...b)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
};

const LIVE = ["accepted", "arrived", "in_progress"];

/** Passenger: create (or reuse) the share link for the trip in progress. */
tripShareRoutes.post("/ride/share", withDb, requireAuth, async (c) => {
  const db = c.get("db");
  const me = c.get("user");
  const ride = (await db.query("select id, status from app.ride_requests where rider_id = $1 and status = any($2) order by id desc limit 1", [me.id, LIVE])).rows[0];
  if (!ride) return c.json({ message: "Start a trip with a driver first, then you can share it." }, 409);
  let row = (await db.query("select token from app.trip_shares where ride_request_id = $1 and user_id = $2 and not revoked and expires_at > now() limit 1", [ride.id, me.id])).rows[0];
  if (!row) row = (await db.query("insert into app.trip_shares (token, ride_request_id, user_id) values ($1,$2,$3) returning token", [newToken(), ride.id, me.id])).rows[0];
  const url = `${new URL(c.req.url).origin}/t/${row.token}`;
  const first = String(me.first_name ?? me.display_name ?? "I").trim() || "I";
  return c.json({ url, token: row.token, message: `${first} is on a DROP trip. Follow it live: ${url}` });
});

/** Passenger: stop sharing. Links made for this trip stop working at once. */
tripShareRoutes.post("/ride/share/stop", withDb, requireAuth, async (c) => {
  await c.get("db").query("update app.trip_shares set revoked = true where user_id = $1 and not revoked", [c.get("user").id]);
  return c.json({ message: "Sharing stopped" });
});

/** Public: what the person with the link sees. Never includes phone numbers. */
tripShareRoutes.get("/share/:token", withDb, async (c) => {
  const db = c.get("db");
  const s = (await db.query(
    `select t.revoked, t.expires_at, r.status, r.pickup_lat, r.pickup_lng, r.pickup_address, r.dropoff_lat, r.dropoff_lng, r.dropoff_address,
            ru.first_name as rider_name, du.first_name as driver_name, du.latitude as dlat, du.longitude as dlng, du.last_location_update_at as dat,
            p.vehicle_make, p.vehicle_model, p.vehicle_colour, p.vehicle_plate
       from app.trip_shares t
       join app.ride_requests r on r.id = t.ride_request_id
       join app.users ru on ru.id = t.user_id
       left join app.users du on du.id = r.driver_id
       left join app.driver_profiles p on p.user_id = r.driver_id
      where t.token = $1`, [c.req.param("token")])).rows[0];
  c.header("Cache-Control", "no-store");
  c.header("X-Robots-Tag", "noindex");
  if (!s || s.revoked || new Date(s.expires_at).getTime() < Date.now()) return c.json({ state: "gone" }, 404);
  const live = LIVE.includes(s.status);
  const tiles = (await mapSettings(db, c.env)).osm_tile_url;
  return c.json({
    state: live ? "live" : s.status === "completed" ? "completed" : "ended",
    status: s.status, tiles,
    rider: s.rider_name,
    pickup: { lat: s.pickup_lat, lng: s.pickup_lng, address: s.pickup_address },
    dropoff: { lat: s.dropoff_lat, lng: s.dropoff_lng, address: s.dropoff_address },
    driver: live && s.driver_name ? {
      name: s.driver_name,
      vehicle: [s.vehicle_colour, s.vehicle_make, s.vehicle_model].filter(Boolean).join(" "),
      plate: s.vehicle_plate,
      location: s.dlat == null ? null : { lat: s.dlat, lng: s.dlng, updated_at: s.dat },
    } : null,
  });
});

/** The page itself. Plain HTML with a map; it asks /api/share/:token for updates every few seconds. */
tripShareRoutes.get("/t/:token", (c) => {
  c.header("Cache-Control", "no-store");
  c.header("X-Robots-Tag", "noindex");
  return c.html(PAGE);
});

const PAGE = `<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="robots" content="noindex"><title>Follow a DROP trip</title>
<link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css">
<style>
:root{--bg:#fff;--fg:#14110f;--mut:#6b6560;--card:#fff8f4;--pri:#e8461a}
@media(prefers-color-scheme:dark){:root{--bg:#000;--fg:#fff;--mut:#b9b2ac;--card:#1a1715}}
html,body{margin:0;height:100%;background:var(--bg);color:var(--fg);font:16px/1.4 system-ui,sans-serif}
#map{position:absolute;inset:0 0 168px 0}
#panel{position:absolute;left:0;right:0;bottom:0;height:168px;box-sizing:border-box;padding:16px;background:var(--card);border-radius:20px 20px 0 0;box-shadow:0 -4px 20px rgba(0,0,0,.15);overflow:auto}
h1{font-size:18px;margin:0 0 4px}.m{color:var(--mut);font-size:14px;margin:2px 0}.b{display:inline-block;background:var(--pri);color:#fff;border-radius:99px;padding:2px 10px;font-size:13px;font-weight:700}
.full{position:absolute;inset:0;display:none;align-items:center;justify-content:center;text-align:center;padding:24px;background:var(--bg);z-index:9999}
</style></head><body>
<div id="map"></div>
<div id="panel"><h1 id="t">Loading trip…</h1><div id="s" class="m"></div><div id="d" class="m"></div><div id="v" class="m"></div></div>
<div id="gone" class="full"><div><h1>This link is no longer active</h1><p class="m">The trip was ended or sharing was stopped.</p></div></div>
<script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
<script>
var token=location.pathname.split('/').pop(),map,car,pk,dp,fitted=false;
var LABEL={accepted:'Driver is on the way',arrived:'Driver has arrived',in_progress:'On the trip'};
function $(i){return document.getElementById(i)}
function dot(c){return L.divIcon({className:'',html:'<div style="width:16px;height:16px;border-radius:50%;background:'+c+';border:3px solid #fff;box-shadow:0 0 4px rgba(0,0,0,.5)"></div>',iconSize:[16,16],iconAnchor:[8,8]})}
function upd(j){
  if(!map){map=L.map('map',{zoomControl:true}).setView([j.pickup.lat,j.pickup.lng],14);
    L.tileLayer(j.tiles,{maxZoom:19,attribution:'&copy; OpenStreetMap contributors'}).addTo(map);
    pk=L.marker([j.pickup.lat,j.pickup.lng],{icon:dot('#1fa463')}).addTo(map);
    dp=L.marker([j.dropoff.lat,j.dropoff.lng],{icon:dot('#14110f')}).addTo(map);}
  $('t').textContent=(j.rider||'Someone')+"'s DROP trip";
  if(j.state==='live'){$('s').innerHTML='<span class="b">'+(LABEL[j.status]||'Live')+'</span>';}
  else{$('s').textContent=j.state==='completed'?'Trip completed':'Trip ended';}
  $('d').textContent='To: '+(j.dropoff.address||'destination');
  var d=j.driver;
  $('v').textContent=d?(d.name+(d.vehicle?' · '+d.vehicle:'')+(d.plate?' · '+d.plate:'')):'';
  if(d&&d.location){var p=[d.location.lat,d.location.lng];
    if(!car)car=L.marker(p,{icon:dot('#e8461a')}).addTo(map);else car.setLatLng(p);
    if(!fitted){map.fitBounds(L.latLngBounds([p,[j.pickup.lat,j.pickup.lng],[j.dropoff.lat,j.dropoff.lng]]).pad(.2));fitted=true;}}
}
function poll(){fetch('/api/share/'+token,{cache:'no-store'}).then(function(r){
  if(r.status===404){$('gone').style.display='flex';return null}return r.json()}).then(function(j){
  if(j){upd(j);if(j.state==='live')setTimeout(poll,5000);}}).catch(function(){setTimeout(poll,8000)})}
poll();
</script></body></html>`;
