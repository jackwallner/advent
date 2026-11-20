# Advent Doors Project Guide

Advent calendar generator from Jack's mom's idea (2026-11-18): pick categories and a budget, one door opens each December day 1 to 24, rate each day, and make one for someone as a link. Ships as a web app (jackwallner.com/ios/advent/) and an iOS app. XcodeGen project/scheme: `Advent`, sim lease owner `advent`.

## Tech Stack
- Swift 6 / SwiftUI, iOS 17+, XcodeGen (`project.yml`). No packages, no RevenueCat, no backend.
- Web: `docs/` (GitHub Pages, mirrored to jackwallner.com/ios/advent/ by `.github/workflows/sync-landing-page.yml`). Plain HTML/JS, no build step.

## IDs
- Bundle `com.jackwallner.advent`, App Store app `6837399320` ("Advent Doors: Daily Calendar"), SKU `advent`.

## Architecture
- `content/items.json`: every door item (352: 8 categories x 24 free, 10 low, 6 medium, 4 high). `python3 content/validate.py` checks it; `python3 scripts/build-web-content.py` writes `docs/content.js`. The iOS app bundles items.json directly.
- `docs/calendar.js` and `Shared/Services/CalendarBuilder.swift` are the same algorithm (seeded mulberry32 pick + door layout). They must stay identical: a gift made in the app opens in a browser. `AdventTests` pins Swift to vectors produced by the JS.
- `Shared/Services/GiftLink.swift` / `giftLink` in docs/index.html: a gift is `https://jackwallner.com/ios/advent/#g=<base64url JSON {y,t,f,m,l,d}>`, days encoded as category letter + item number. No server.
- `Shared/Services/CalendarStore.swift`: own calendar + opened/ratings in UserDefaults. Doors unlock by local date (`CalendarBuilder.unlocked`).
- Views: `SetupView` (categories, budget, gift fields), `CalendarView` + `BoardView` (24 doors, 4 wide), `DaySheet`, `GiftFlow` (share link, preview).

## Rules that hold everywhere
- Never renumber or delete item ids in items.json; only append or edit text. Old gift links reference ids.
- Any change to the pick/layout logic must change both JS and Swift, then regenerate the vectors in `AdventTests/CalendarBuilderTests.swift` from `docs/calendar.js` and run `node scripts/test-web.mjs`.
- Debug-only peeking: iOS DEBUG builds read `-DebugDay N` and have a debug section in the menu; the web honors `?day=N`.
- No em dashes in copy, content or comments (validate.py enforces it for content).

## App-specific notes
- Ratings ask: after a door is rated and its sheet closes (`ReviewPromptTracker`, fleet rules).
- Reminders: local notifications at 8 AM on each remaining December day (`Reminders.swift`), asked for when the calendar is made.
- Tests: `xcodebuild test` (unit + `JourneyUITests`, which attaches screenshots), `node scripts/test-web.mjs` for the web.

---
Shared iOS conventions (build, simulator, release/TestFlight, ASC key, signing, ratings ask, gotchas):
the global agent rules + the `ios-dev` skill.
