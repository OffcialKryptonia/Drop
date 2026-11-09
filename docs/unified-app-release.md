# Unified DROP app: release plan

One app, `com.kryptonia.drop`. Passenger mode is the default; approved drivers switch to driver mode from the side menu.
The old driver app (`com.kryptonia.dropdriver`) is retired: its code lives on inside `apps/drop/lib/driver/`, and the old folder is in git history.

## Already decided
- Fresh start: there are no live users to migrate from the old Laravel database.
- A person who is also a driver has two separate wallets (passenger and driver).
- Driver location is shared only while the driver is online and the app is open. Background location is not requested.

## What works now
- Sign-up and sign-in, passenger wallet, top-up.
- "Become a driver" online application, admin review in the web admin (Driver applications), mode switch.
- Driver home: online/offline with wallet and document checks, location pings.
- Rides backend: requests, matching (first accept wins), trip states, cash/wallet settlement, cancellation fees, history.
- Passenger home: pick drop-off on the map, ride types with server prices, request, follow the driver, receipt.
- Driver home: incoming request cards, accept/decline, navigate, arrived / start / complete, cancel.

## What is not built yet (blocks a public launch)
1. Ratings and reviews, scheduled rides, waiting-time charges, card payments for trips.
2. Driver earnings, payouts/withdrawals and trip history screens, passenger ride history screen (the copied old screens expect the old API).
3. Push notifications for requests and application decisions (devices table, OneSignal). Until then requests are picked up by polling every 4 seconds while the driver app is open.
4. Server-driven text for the new screens (currently English strings in code).
5. Live tracking through Firestore (polling every 4 seconds for now).

## Before the first store build
- Firebase: add SHA-1/SHA-256 fingerprints to `com.kryptonia.drop`; confirm `google-services.json` / `GoogleService-Info.plist` belong to that app ID; remove `com.kryptonia.dropdriver` afterwards.
- Maps: Admin → Maps switches Google / OpenStreetMap (see docs/maps-setup.md); Google keys are only needed for Google mode. Google Maps API key (Android manifest and iOS) is required for the passenger map in Google mode; restricted to `com.kryptonia.drop`.
- Android: release keystore, versionCode, Play Console listing. Location permission declaration covers foreground use only.
- iOS: Apple Developer bundle ID `com.kryptonia.drop`, location usage strings reviewed, push capability.
- Run `flutter analyze` and a real-device pass through: sign-up, top-up, apply as driver, admin approves, switch mode, go online, switch back, then a full test trip: request, accept, arrive, start, complete (cash and wallet).
- Worker: deployed from `main`, secrets set in the Cloudflare dashboard, R2 bucket `drop-docs` bound.

## Rollout order
1. Internal testing build to your own phones (Android internal track / TestFlight).
2. Closed beta with a few drivers: apply, get approved, go online (no trips yet).
3. Ship once the rides backend and driver trip screens are done and a full test trip works end to end.
