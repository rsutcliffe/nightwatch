# Brand tokens

Copied from the Mac app's `Tokens.swift` so the two look like one product. The Mac's tokens use `NSColor` and cannot be
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
