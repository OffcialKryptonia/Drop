# Website asset sources and replacement list

## Brand assets (supplied by the client)
- `worker/public/assets/logo-light.png`, `logo-dark.png`, `symbol.png`: derived from the supplied horizontal DROP logo (cropped, background removed, wordmark recoloured white for dark backgrounds). Symbol artwork unchanged.
- `favicon-32.png`, `favicon-192.png`, `apple-touch-icon.png`: from the supplied standalone symbol.
- `og.jpg`: the supplied red app icon artwork, centred on its own red background.
- `logo-reveal-dark.mp4/.jpg`, `logo-reveal-light.mp4/.jpg`: the two supplied logo animations, re-encoded (audio removed, 1280px wide). Only the dark one is used on the page.

## Photographs: PLACEHOLDERS, replace with DROP's own photography
All three are free to use under the [Unsplash License](https://unsplash.com/license) (commercial use allowed, no permission needed, credit appreciated). They are loaded from Unsplash's image CDN. They are stock images, not DROP trips, drivers or customers, and no DROP location is implied.

| Where | Photo | Photographer | Link |
|---|---|---|---|
| Hero | Busy street in Lagos | Opeyemi Adisa | https://unsplash.com/photos/cFT_Xq4XyA0 |
| Passenger section | Woman at a yellow bus window, Lagos | Ben Iwara | https://unsplash.com/photos/i-XBdBCc0Yc |
| Driver section | Man in a car's driver seat | Omotayo Tajudeen | https://unsplash.com/photos/5OOUed0eWAU |

To replace: put new files in `worker/public/assets/`, update the `<img>` tags in `worker/public/index.html`, and remove the credit links.

## Font
Outfit, SIL Open Font License (`assets/fonts/OFL-Outfit.txt`), self-hosted.

## Still needed from DROP
- Real social profile links (footer currently points to https://instagram.com and https://x.com).
- Play Store and App Store URLs (buttons are "coming soon").
- Final privacy policy and terms (current pages are marked draft and `noindex`).
- Domain: canonical, Open Graph and structured-data URLs assume `https://drop.taxi/`. Change them if the live domain differs.
- Real app screenshots, if you want them shown (none were supplied, none were invented).
