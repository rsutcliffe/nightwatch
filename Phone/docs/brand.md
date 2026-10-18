# Brand tokens

Copied from the Mac app's `Tokens.swift` so the two look like one product. **Exception, 18 October 2026:** the Tonight screen on
iPad and iPhone has a deliberate, owner-approved "Photographic" look that the Mac app does not share (see the next section).
Everything else below still matches the Mac. The Mac's tokens use `NSColor` and cannot be
imported on iOS; this app's `PhoneTokens` will carry these values with `UIColor` high-contrast variants.

## Normal (dark)

| Token | Value | Use |
|---|---|---|
| background | `#14171D` | page |
| card | `#1C1F27` | cards and tiles |
| track | `#272A34` | bar gaps, outlines, timeline tracks |
| text.primary | `#E8EAEF` | body |
| text.secondary | `#A8AEBE` | supporting text (brighter, `#CDD2DC`, under Increase Contrast) |
| accent.clear | system accent (blue with Multicolour) | clear-sky bars, bezel ticks, links |
| control.on | `#0A84FF` | switches |
| status.warning | `#EDB40D` | warnings, such as Dew risk: High |
| glass.hairline | white 12 % (45 % under Increase Contrast) | outlines |
| surface.tile | white 6 % (12 %) | tiles |
| surface.track | white 7 % | empty bar track |
| bar.cloudy | white 35 % | bars outside a clear window |

The sky-score bezel is a 60-tick 12-hour dial: outer radius 45.5 pt, hour ticks 8 by 1.7, minute ticks 4.5 by 1.1; lit
ticks use the accent with one glow. Verdict wording, bars and tiles come from SkyCore, not from this file.

## Photographic look (iPad and iPhone, from 18 October 2026)

The owner found the iPad design basic and clunky, so Tonight now sits on a full-bleed night-sky photograph, with a very large
light score numeral and frosted-glass cards. The Mac app keeps its current look; this divergence is on purpose and applies
to iPad and iPhone only. Red night mode is unchanged: one hue on black, the photograph tinted red.

| Token | Value | Use |
|---|---|---|
| gold | `#F2D49B` (red mode: the red accent) | emphasis only: hours clear, the dew line, lit parts |
| glass.fill | white 9 % (red mode: `#A0140C` at 10 %) | cards over the photograph |
| glass.hairline | white 16 % (35 % red; text colour under Increase Contrast) | card outline, 16 pt radius |
| scrim | background colour at 16 % over the top to 78 % at the foot | holds text contrast over the photo |

- **Backdrop:** `night-sky-wide.jpg` (iPad landscape) and `night-sky-tall.jpg` (portrait, iPhone), cropped from the owner-supplied
  night-sky photograph, in `App/Resources/Backdrop`. The Unsplash Milky Way (William Zhang, credited in the README) is the
  fallback if either file is missing.
- **Hero:** numeral about 120 pt on iPad landscape, 104 pt on iPad portrait, 80 pt on iPhone, light weight, scaled with Dynamic Type;
  "SKY SCORE" in wide-tracked capitals; the clear window in large light type; hours clear and the dew line in gold.
- **Cards:** the three best targets as glass cards with a brightened picture; a card a line on iPhone.
- **System blue** is left to controls the system draws; the call to action is a pale pill.
- **Accessibility:** under Reduce Transparency the glass becomes the solid card and the photograph is dropped. At the accessibility
  text sizes the cards are solid and the scrim is near-opaque (88 to 92 %), so text never sits on the picture.
- The Mac's 60-tick score bezel is not drawn on Tonight now; `ScoreBezelView` remains in the code until the owner decides whether
  to bring it back as a thin ring round the numeral.

## Red night mode

Every colour becomes a red-only tone on black, so nothing else reaches the eye. No yellow: a warning is a dashed outline, a
"!" and bold text. The Apple Weather mark is never tinted.

| Token | Value |
|---|---|
| background | `#000000` |
| card | `#120000` |
| track | `#2E0000` |
| text.primary | `#E0281C` |
| text.secondary | `#8F1710` |
| accent.clear (lit bars, ticks) | `#FF2A1A`, one glow |
| bar.cloudy | `#A0140C` at 55 % |
| hairline | `#2E0000` |
| warning | accent red, dashed outline, "!" and bold |

Contrast of the dim reds against Dynamic Type and Increase Contrast is checked in the design pass; if `#8F1710` supporting
text is too dim, raise it before dimming anything else. Stored per device, never synced.
