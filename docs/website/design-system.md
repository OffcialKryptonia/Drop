# DROP website design system

Source: `worker/public/assets/site.css` (all values are CSS variables on `:root`). Reuse these tokens for future DROP web properties.

## Colour (measured from the supplied logo and app icon)
| Token | Hex | Use |
|---|---|---|
| `--drop-orange` | `#FD5901` | Logo gradient midpoint. Route line, small accents, never body text |
| `--drop-amber` | `#FC9600` | Logo gradient light end |
| `--drop-flame` | `#FC2E00` | Logo gradient red end |
| `--drop-red` | `#DD3315` | App icon red. Primary buttons, key words, closing marks (white text on it passes AA) |
| `--drop-red-deep` | `#B72A10` | Button hover |
| `--ink` | `#151515` | Headings, dark sections |
| `--ink-soft` / `--ink-mute` | `#3B3835` / `#6A645E` | Body / secondary text on light |
| `--on-dark-mute` | `#B9B2AA` | Secondary text on ink |
| `--warm` | `#FAF6F1` | Warm off-white sections |
| `--paper` / `--line` | `#FFFFFF` / `#E6DED5` | Background / dividers |

Orange is used sparingly: one primary action per view, the route line, and the closing sections. The full-colour logo is only placed on white, warm white or near-black (it loses contrast on red).

## Typography
- Display: Outfit (variable, self-hosted, Latin subset, SIL OFL), weights 500-800, tight tracking.
- Body: system UI stack (no download).
- Display scale: `--step-4` 40-84px (hero), `--step-3` 32-52px (section headings), `--step-2` 24-32px. Body: `--step-0` 16-17px, `--step-1` 19-22px (lead), `--step--1` 13-14px (notes). Lines stay under about 70 characters.

## Spacing, layout, shape
- 4px base: `--s1` 4px to `--s9` 112px. Sections use `clamp(72px, 9vw, 112px)` vertical padding.
- Container `--wide` 76rem (84rem from 1440px), side gutter `clamp(20px, 4vw, 48px)`. Reading measure 38rem.
- Radius: 6px on buttons, photos and callouts. Nothing else is rounded (the route markers are circles because they are stops).
- Signature device: the slant (`--slant`) copies the angle of the logo's motion bars. It cuts the hero photo and the mobile-menu markers.

## Components
- Buttons: `.btn-primary` (red), `.btn-ghost` (outlined), disabled "coming soon" buttons use a dashed outline and `aria-disabled`. Minimum height 48px.
- Navigation: sticky white bar; full-screen ink menu on mobile (below 1024px) with Esc, link-click and focus handling.
- Lists use rules, not cards. The "How it works" route is numbered because the steps are a sequence.
- Images: 6px radius, `object-fit: cover`, credit link bottom-right, lazy-loaded below the fold.
- Focus: 3px ink outline (white on dark) on every interactive element.

## Breakpoints
Mobile first. Tablet at 48em (768px), desktop at 64em (1024px), large at 90em (1440px). Tested at 360, 390, 430, 768, 1280 and 1920 wide.

## Motion
One orchestrated hero entrance (three headline beats, then copy, buttons, and a slanted photo wipe) and the logo reveal video playing once when scrolled into view. Everything else is a state change in response to the user (menu, accordion, hover). `prefers-reduced-motion` disables the entrance and the video (the poster shows the final frame).
