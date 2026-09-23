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
