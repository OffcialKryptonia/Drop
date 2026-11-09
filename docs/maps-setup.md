# Maps: Google Maps and OpenStreetMap

DROP can draw maps and price routes with **Google Maps** or **OpenStreetMap (OSM)**. The admin picks the mode in
**Admin → Operations → Maps**:

| Mode | What happens |
|---|---|
| Automatic (default) | Google while its server key is set and answering; otherwise OpenStreetMap. If Google fails to answer a route request, DROP uses OpenStreetMap for the next 30 minutes, then tries Google again. |
| Always Google Maps | Forces Google. Route pricing still falls back to OSM, then to a straight-line estimate, so fares never fail. |
| Always OpenStreetMap | Forces OSM everywhere. No Google account or keys needed. |

The passenger app asks the server which mode to use every time it opens, so the switch takes effect without a new app release.
Automatic cannot see whether the *Android/iOS map key inside the app* is valid. If the map is blank on phones while the server key
is set, choose "Always OpenStreetMap".

## OpenStreetMap: what to set up

OpenStreetMap has **no account, no API key and no billing** for using the map. An openstreetmap.org login is only for editing the map.
What you need is somewhere to fetch map pictures (tiles) and routes from:

1. **Testing (free, no sign-up):** the defaults already work: tiles `https://tile.openstreetmap.org/{z}/{x}/{y}.png` and routes
   `https://router.project-osrm.org`. Both are community servers with a fair-use policy: fine for your own testing, **not for real traffic**.
2. **Real traffic:** use a provider and paste its addresses in the Maps page.
   - Tiles: sign up with **MapTiler** (maptiler.com, free tier) or **Stadia Maps** (stadiamaps.com). Create a key and paste the
     raster tile URL, for example `https://api.maptiler.com/maps/streets-v2/{z}/{x}/{y}.png?key=YOUR_KEY`.
   - Routes: **OpenRouteService** and **GraphHopper** have free tiers but a different API from OSRM; DROP currently speaks OSRM.
     For OSRM at scale, run your own OSRM server (or tell me and I will add OpenRouteService support).
3. Keep the attribution "© OpenStreetMap contributors" visible. The app shows it on the map.

## Google Maps keys (when its console works)
- Android key: Maps SDK for Android, restricted to `com.kryptonia.drop` + SHA-1 (test key SHA-1 is in the Android test build workflow summary).
- iOS key: Maps SDK for iOS, restricted to bundle ID `com.kryptonia.drop`.
- Server key: Routes API; set as the Worker secret `GOOGLE_MAPS_SERVER_KEY`.
