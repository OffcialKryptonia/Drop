# Website asset sources and replacement list

## Brand assets (supplied by the client)
- `worker/public/assets/logo-light.png`, `logo-dark.png`, `symbol.png`: derived from the supplied horizontal DROP logo (cropped, background removed, wordmark recoloured white for dark backgrounds). Symbol artwork unchanged.
- `favicon-32.png`, `favicon-192.png`, `apple-touch-icon.png`: from the supplied standalone symbol.
- `og.jpg`: the supplied red app icon artwork, centred on its own red background.
- `logo-reveal-dark.mp4/.jpg`, `logo-reveal-light.mp4/.jpg`: the two supplied logo animations, re-encoded (audio removed, 1280px wide). Only the dark one is used on the page.

## Photographs (supplied by the client)
The three pictures are supplied by DROP and stored in `worker/public/assets/photos/` as WebP (two sizes each). No third-party stock photos or hotlinks remain on the site. They appear to be generated or illustrative images, not real DROP trips, drivers or customers, so no real person or DROP location is implied. Replace with real photography when available.

| Where | File | Shows |
|---|---|---|
| Hero | `hero-street-*.webp` | Grey sedan on a busy street with yellow buses, golden hour |
| Passenger section | `passenger-waiting-*.webp` | Woman waiting beside a DROP-branded car, phone in hand |
| Driver section | `driver-car-*.webp` | Smiling driver in a white car with the DROP logo |

To replace: add new files in `worker/public/assets/photos/`, update the `<img>` tags in `worker/public/index.html`, and adjust `object-position` in `assets/site.css` if the subject is cropped.

## Font
Outfit, SIL Open Font License (`assets/fonts/OFL-Outfit.txt`), self-hosted.

## Still needed from DROP
- Real social profile links (footer currently points to https://instagram.com and https://x.com).
- Play Store and App Store URLs (buttons are "coming soon").
- Final privacy policy and terms (current pages are marked draft and `noindex`).
- Domain: canonical, Open Graph and structured-data URLs assume `https://drop.taxi/`. Change them if the live domain differs.
- Real app screenshots, if you want them shown (none were supplied, none were invented).
