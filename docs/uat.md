# Nightwatch UAT

Run on each Mac after `scripts/build-app.sh`.

1. Menu bar shows a star; no Dock icon. → pass when both true.
2. Click the star: popover shows site, score ring, window or "Nothing to see here", cloud strip, six tiles, best three targets, updated time. → pass when all visible within one second.
3. Settings › add your real site, choose it as Active, pick your telescope preset. Close. Popover updates. → pass when the site name changes in the header.
4. Targets window: Nebulae group shows cards with DSS thumbnails; `ls ~/Library/Caches/Nightwatch/thumbs` grows. → pass when at least three jpgs exist.
5. Events group lists at least one item (a meteor shower is active most of the year). → pass.
6. Notifications: System Settings › Notifications shows Nightwatch allowed. Force a go alert by setting Go rule "Cloud at most 60%" on a night with any window and quitting/relaunching after 17:00 local. → pass when a banner arrives.
7. Quit Wi-Fi, wait, reopen popover: "Off the beat since HH:MM" appears after six hours, icon shows star.slash. → pass (long test; optional).
8. Plain wording: Settings › Wording › Plain. Refresh button reads "Refresh". → pass.
9. Targets › Dark sites lists the Yorkshire Dales and North York Moors from the Sheffield test site at 120 km, each with tonight's score. → pass.
10. Settings › Dark sites › radius 20 km → the list empties or shrinks within one Patrol. → pass.
11. A card's "Use as beat" adds the site under Beats and the popover header changes to it. → pass.
12. With the grid installed, at least one "Dark spot" card appears within 50 km of a rural site. → pass.
13. Settings › Bright nights on, on a night with no astronomical darkness (or with Go rule hours set above tonight's darkness): the popover says "Bright night: Moon and planets" with a window when the Moon or a planet is 15° up in a clear run. → pass.
14. Bright nights off: the same night shows "Nothing to see here" with the reason line, as 0.2.2. → pass.
15. A September night with a clear dark window: the verdict is "Clear window tonight" whatever the Bright nights setting. → pass.
16. Popover "Clearer sky …" line → Targets opens on Dark sites with that card at the top; cards show "Score N vs M at home". → pass.
17. `ls ~/Library/Caches/Nightwatch/sites` after a Patrol lists only current sites. → pass.
18. Settings › Aurora on, threshold Amber: on an amber or red AuroraWatch UK status after dark with a clear sky, outside quiet hours, a notification arrives and the popover shows "Aurora: amber (AuroraWatch UK)" in AuroraWatch's amber (#ff9900); under cloud, no notification. → pass.
19. macOS 26 or later: the popover panel, tiles and Targets cards are frosted glass; with Reduce transparency on they are a solid dark fill with the same layout. → pass.
20. Popover: the sky score sits in a 60-tick bezel whose ticks glow red across tonight's clear window; with a bright Moon up the line under the window time reads "Held back by a N% moon". → pass.
21. Popover: clear-sky bars (taller = clearer) with the window hours red; the Moon tile shows the Moon, "N%" and "Sets HH:MM"; on a damp night the Dew risk tile is amber with "Dew heater advised". → pass.
22. Popover: three cards read "ID / name / Best HH:MM · N° up"; the footer switch reads "Notify at HH:MM"; Patrol refreshes the update time. → pass.
23. Targets: every card shows a track across the clear window, lit red where the target is viewable and brighter where higher, a white dot at the best moment, and "Viewable HH:MM–HH:MM · Best HH:MM · N°". → pass.
24. Targets: titles read "IC 1340  Eastern Veil" with a magnitude on every card; a neutral "Fills N% of frame" chip disappears when "Fits my field of view" is on. → pass.
25. Targets: the header has a slim clear-sky strip and a sort control that reorders the cards; the sidebar is glass with a white highlight and the arrow keys move through it; the filters are switches under an amber Moon line. → pass.
26. Contrast: open the popover over a white window and run `swift scripts/contrast.swift` → every token prints "pass" (4.5:1 or better). → pass.
27. Signed build, after a Patrol: `~/Library/Caches/Nightwatch/forecast.json` contains "secondOpinion" with source "Open-Meteo". → pass.
28. Popover: under the window time, "Open-Meteo agrees" with a tick, or "Open-Meteo agrees: no clear window" when neither sees one, or an amber-dot line where it differs ("sees cloud from HH:MM", "sees it clear from HH:MM", "has a clear run HH:MM–HH:MM", "sees no clear window"); the evening heads-up and the nudge end with the same sentence. → pass.
29. Settings › Alerts: "Alert only when Open-Meteo agrees" is off by default and enabled on the signed build; with it on, a night where Open-Meteo is not clear inside the window sends no heads-up. → pass.
30. Signed build with Xcode and xcodegen: `scripts/build-app.sh` prints "Widget: built and embedded"; with the Command Line Tools only it prints "Widget: skipped (Xcode not installed)", and on an unsigned build "Widget: skipped (unsigned build; …)"; either way the app still builds. → pass.
31. Right-click the desktop › Edit Widgets… › Nightwatch lists small, medium and large with the porthole icon; before the app has patrolled, the gallery shows a sample night. → pass.
32. On the desktop, each size shows tonight's score and the popover's verdict with nothing cut off; the small one is centred; medium and large show the reason and Open-Meteo's line. → pass.
33. After a Patrol the widgets update within a minute; with the forecast over six hours old they show an amber "Forecast N h old". → pass.
34. Click any widget → the Targets window comes to the front, centred on first open. → pass.
35. On a clear night, click a target row on the large widget → the Targets window opens on that target's detail. `open nightwatch://target/NGC0147` from Terminal does the same. → pass.
36. About shows version 0.6.4.
37. Targets › Constellations: every card shows its figure artwork with the star plot on top, not a stick figure; opening one shows the same art larger, with no "dashed = your field of view" note. → pass.
38. Signed build, after a heads-up or nudge: when Apple Weather and Open-Meteo both lose the window, "Stand down. Clouds moving in" arrives with "Apple Weather and Open-Meteo both see cloud."; when only one does, "Hold fire. Forecasts disagree" arrives at most once a night, saying what each sees; if both clear again before the nudge, the nudge still fires. → pass.
39. Targets: open a nebula, a large nebula (NGC 7000), a constellation and a planet. Each image fills the page with its text in black caption boxes. The large nebula's dashed box sits fully inside the clear space above the caption. On a clear night the caption shows the four figures and a labelled altitude chart, red only inside the window. → pass.
40. The small desktop widget's score bezel and text sit centred left to right. → open: a few points left of centre on the owner's desktop at 0.6.4.
