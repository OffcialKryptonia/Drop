# Firebase (project `drop-260fc`)

- Apps registered: `com.kryptonia.drop` (the unified app: passenger and driver). `com.kryptonia.dropdriver` is retired; remove it from the Firebase project once the unified app is live.
- Firestore (default), production mode, rules in `firestore.rules` (published by hand in the console).
- Auth: Email/Password enabled. Phone and Google sign-in need the signing key SHA-1/SHA-256 first.
- `google-services.json` is NOT committed (see .gitignore); it is supplied to builds as a CI secret.
- TODO: tighten rules once the Worker owns ride/user writes (writes then go through the Firestore REST API with a service account, which bypasses rules).
