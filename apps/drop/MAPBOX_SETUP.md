# Mapbox integration setup

Drop now supports Mapbox as an optional renderer alongside Google Maps and OpenStreetMap/MapLibre. The runtime public token and style are managed from **Admin → Maps**; no token is compiled into the Flutter app.

## 1. Configure Worker encryption

Set the existing Cloudflare Worker secret `SETTINGS_ENCRYPTION_KEY` to a random value of at least 32 characters. It is used to encrypt the saved Mapbox public token at rest. Do not commit it or send it to the mobile app.

## 2. Create a restricted public token

In your Mapbox account, create a **public** access token beginning with `pk.`. Grant only the public read scopes needed to load styles, fonts and map tiles. Apply available application/URL restrictions appropriate to your deployment. Do not use an `sk.` secret token as the app's runtime token.

## 3. Configure Admin → Maps

1. Enter the public `pk.` token and optionally a Mapbox Studio style URI (for example `mapbox://styles/mapbox/streets-v12`).
2. Save the configuration.
3. Select **Test Connection**. The Worker checks that the token can read the configured style and stores the verification timestamp.
4. Enable Mapbox.
5. Select Mapbox as the map provider and save.
6. Optionally enable **Use Mapbox for Region Bordering**. This draws the existing active service-region polygons and enables local GeoJSON boundary-transition hints in the app.

Replacing the token or changing the style invalidates the previous connection test and temporarily disables Mapbox until the new configuration is tested and enabled again. Disabling Mapbox while it is selected returns provider selection to Automatic. The API never returns a secret token; the public token is returned to the app only when Mapbox is the active renderer.

## 4. Native SDK build credentials

The app uses `mapbox_maps_flutter` 2.31.1. The public `pk.` token is loaded dynamically from `/map-config` at runtime. Some Mapbox native SDK distributions may also request a separate **build-time** SDK registry credential with only the `DOWNLOADS:READ` scope. This is not the app token and is never stored in Worker settings.

If the Android Gradle build requests it, add a GitHub Actions repository secret named `SDK_REGISTRY_TOKEN`. The Android test-build workflow passes it to Gradle without writing it into the repository. For local Android builds, place it in your user-level `~/.gradle/gradle.properties`:

```properties
SDK_REGISTRY_TOKEN=your_restricted_downloads_read_token
```

For local iOS builds, if CocoaPods requests Mapbox repository authentication, use your user-level `~/.netrc`:

```text
machine api.mapbox.com
  login mapbox
  password your_restricted_downloads_read_token
```

Never commit either file or the `sk.` token. Recent SDK releases may not require this additional download credential; only configure it if the native build requests it.

## 5. Region authority and fallback

The Worker/PostGIS region endpoints remain authoritative. Mapbox receives the existing active region coordinates as GeoJSON for polygon fill/outline rendering. When GPS accuracy is 80 metres or better, the client may use point-in-polygon and 100-metre edge-proximity checks to request an earlier server validation after a polygon transition (with a 20-second probe cooldown). The client never changes a region itself. The existing confirmation dialog, `region/at`, `region/me`, ride checks and service-equivalence checks remain in place.

If Mapbox style loading fails, the shared map widget reports the fallback and renders the existing MapLibre/OSM map. Routing, geocoding, address search and directions remain on their existing services.

## 6. Attribution

The Mapbox SDK's built-in logo and attribution controls are left enabled. Keep them visible; they also provide the SDK's telemetry opt-out affordance. OpenStreetMap attribution remains in place on the existing OSM/MapLibre renderer.

## 7. Build compatibility

The repository's Android test workflow uses Flutter 3.47.x. The selected Mapbox Flutter v2 package requires Dart 3.6 or newer; the app's minimum Dart constraint is set accordingly. No Flutter, Gradle, Android SDK or unrelated package upgrade is included. Changing provider, token or style in Admin does not require an APK rebuild after this integration has been shipped.
