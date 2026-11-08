# Test signing key (NOT for the Play Store)

`drop-test.jks` signs the internal test APKs built by the "Android test build" GitHub Action, so every
test build has the same fingerprint and the Google Maps / Firebase restrictions keep working.

- Alias `droptest`, store and key password `droptest123`.
- Anyone with repo access can sign with it. That is fine for test builds and unacceptable for a store release.
- The real release keystore is created later and kept only in GitHub secrets / Play App Signing.
