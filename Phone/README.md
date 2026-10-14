# Nightwatch for iPhone and iPad

A free companion to the [Nightwatch](https://github.com/rsutcliffe/nightwatch) Mac app, in development. It will tell you
whether tonight is worth setting up the telescope and alert you on your phone.

This repository holds the phone app and `PhoneCore`, its tested core. The sky maths is the Mac app's `SkyCore` package,
pinned by revision in `Package.swift`.

- Requirements and design: [docs/PRD.md](docs/PRD.md), [docs/brand.md](docs/brand.md)
- Tests: `scripts/test.sh`

What it does:

- **Tonight:** the score, the clear window, the clear-sky hours, the Moon, and the best targets, with alerts before sunset.
- **Plan, Targets, Favourites and the week ahead,** with the Mac app's rules, so hearts and plan choices travel between devices.
- **Eyes and binoculars and Events:** what can be seen without a telescope, showers, comets, space station passes and the Moon
  covering a star.
- **Dark sites** within reach, with tonight's score at each, and observing from one without saving it.
- **Horizons:** the heights of what is in the way, the hills found from elevation data, or measured from a photo.
- **Red night mode**, and a small, medium and large home-screen widget whose target rows open the target.
- **Siri, Spotlight and Shortcuts:** sky score, clear window, best targets, events, show a target, refresh and notifications on or off.
- **Aurora alerts**, telescope and go-rule editing, and "What the numbers mean".

Not yet released.

## Credits

- Milky Way photograph behind the Tonight screen: [William Zhang](https://unsplash.com/@cyclens_) on [Unsplash](https://unsplash.com/photos/blue-and-white-starry-night-sky-hqKPgEVEc-8), under the Unsplash License.
- Constellation and Milky Way line art: the Nightwatch Mac app's artwork, by its author.
- Moon pictures: NASA Scientific Visualization Studio. Sky photographs: DSS2 through CDS Strasbourg. Weather: Apple Weather, Open-Meteo, [MET Norway](https://api.met.no/) (CC BY 4.0, used when the earlier sources cannot be read) and 7Timer! (the last resort, and seeing).
- Light-pollution grids: made using VIIRS Nighttime Lights data (Earth Observation Group, Colorado School of Mines), as in the Nightwatch Mac app.
