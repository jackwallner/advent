# Advent Doors Project Guide

Advent calendar generator from Jack's mom's idea (2026-11-18): pick categories and a budget, one door opens each December day 1 to 24, rate each day, and make one for someone as a link. Ships as a web app (jackwallner.com/ios/advent/) and an iOS app. XcodeGen project/scheme: `Advent`, sim lease owner `advent`.

## Tech Stack
- Swift 6 / SwiftUI, iOS 17+, XcodeGen (`project.yml`). No packages, no RevenueCat, no backend.
- Web: `docs/` (GitHub Pages, mirrored to jackwallner.com/ios/advent/ by `.github/workflows/sync-landing-page.yml`). Plain HTML/JS, no build step.

## IDs
- Bundle `com.jackwallner.advent`, App Store app `6837399320` ("Advent Doors: Daily Calendar"), SKU `advent`.

## Architecture
- `content/items.json`: every door item (352: 8 categories x 24 free, 10 low, 6 medium, 4 high). `python3 content/validate.py` checks it; `python3 scripts/build-web-content.py` writes `docs/content.js`. The iOS app bundles items.json directly.
- `docs/calendar.js` and `Shared/Services/CalendarBuilder.swift` are the same algorithm (seeded mulberry32 pick, house layout, rating steer). They must stay identical: a gift made in the app opens in a browser. `AdventTests` pins Swift to vectors produced by the JS.
- The calendar is a house at night: 24 shuttered windows in a 400 by 720 design space (`slot` in `docs/scene.js`, `HouseGeometry` in `Advent/Views/HouseView.swift`). Slot 0 is the attic, 1 to 20 the five floors, 21 and 23 the ground floor, 22 the front door, always day 24. Opening a day swings its shutters and lights the window; the first open shows the card under frost to wipe away. Three houses (`THEMES` / `HouseStyle.all`, same order and colors on both sides).
- Ratings steer: the first rating of a day swaps one door that is still locked (4 or 5 stars brings one more of that category, 1 or 2 swaps the next one away). Own calendars only; gifts are fixed by their link.
- `Shared/Services/GiftLink.swift` / `giftLink` in docs/index.html: a gift is `https://jackwallner.com/ios/advent/#g=<base64url JSON {y,t,f,m,l,d,h}>`, days encoded as category letter + item number, `h` the house (left out for house 0). No server.
- `Shared/Services/CalendarStore.swift`: own calendar + opened/ratings in UserDefaults. Doors unlock by local date (`CalendarBuilder.unlocked`).
- Views: `SetupView` (categories, budget, house, gift fields), `CalendarView` + `HouseScene` (sky, house, snow, card overlay), `HouseView` (house and windows), `DayCard` (card, `FrostView`, `NoteCard`), `Scene` (sky, aurora, moon phase, snow that follows tilt), `GiftFlow` (share link, preview). `Bells.swift` synthesizes the chimes; the web does the same with WebAudio in `docs/scene.js`. No audio or image assets.
- Icon and link preview art: `design/icon.html` and `design/og.html` (the preview reuses `docs/scene.js`). Serve the repo root, screenshot at 1024x1024 and 1200x630, save without alpha.

## Rules that hold everywhere
- Never renumber or delete item ids in items.json; only append or edit text. Old gift links reference ids.
- Any change to the pick/layout logic must change both JS and Swift, then regenerate the vectors in `AdventTests/CalendarBuilderTests.swift` from `docs/calendar.js` and run `node scripts/test-web.mjs`.
- Debug-only peeking: iOS DEBUG builds read `-DebugDay N` and have a debug section in the menu; the web honors `?day=N`.
- No em dashes in copy, content or comments (validate.py enforces it for content).

## App-specific notes
- Ratings ask: after a door is rated and its card closes (`ReviewPromptTracker`, fleet rules).
- Reminders: local notifications at 8 AM on each remaining December day (`Reminders.swift`), asked for when the calendar is made.
- Tests: `xcodebuild test` (unit + `JourneyUITests`, which attaches screenshots), `node scripts/test-web.mjs` for the web. UI tests tap the `frost` button to melt the frost, and launch with `-StillScene` (`Motion.still`) so the snow and twinkle hold still; without it XCUITest never sees the app go idle and the run times out.
- Motion is decoration only: every animation is off under Reduce Motion, where a first open skips the frost.

---
Shared iOS conventions (build, simulator, release/TestFlight, ASC key, signing, ratings ask, gotchas):
the global agent rules + the `ios-dev` skill.
