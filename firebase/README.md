# Firebase (project `drop-260fc`)

- Apps registered: `com.kryptonia.drop` (rider), `com.kryptonia.dropdriver` (driver).
- Firestore (default), production mode, rules in `firestore.rules` (published by hand in the console).
- Auth: Email/Password enabled. Phone and Google sign-in need the signing key SHA-1/SHA-256 first.
- `google-services.json` is NOT committed (see .gitignore); it is supplied to builds as a CI secret.
- TODO: tighten rules once the Worker owns ride/user writes (writes then go through the Firestore REST API with a service account, which bypasses rules).
