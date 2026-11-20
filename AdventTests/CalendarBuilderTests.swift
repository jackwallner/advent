import XCTest
@testable import Advent

/// Vectors produced by docs/calendar.js (scripts/test-web.mjs inputs). If these fail, a gift made in the
/// app would open as a different calendar on the web.
private enum JSVectors {
    static let vecA = ["food-36", "family-36", "food-39", "family-26", "food-11", "family-32", "food-32", "family-28", "food-05", "family-18", "food-26", "family-30", "food-07", "family-37", "food-28", "family-24", "food-02", "family-35", "food-16", "family-11", "food-33", "family-08", "food-35", "family-22"]
    static let vecB = ["selfcare-23", "books-30", "selfcare-28", "books-14", "selfcare-38", "humor-31", "family-26", "humor-37", "food-37", "fitness-16", "food-41", "music-09", "selfcare-43", "music-38", "fitness-42", "music-28", "humor-12", "puzzles-29", "food-24", "music-44", "books-39", "family-19", "puzzles-37", "puzzles-09"]
    static let vecC = ["humor-19", "humor-11", "humor-10", "humor-07", "humor-08", "humor-23", "humor-05", "humor-22", "humor-12", "humor-01", "humor-17", "humor-24", "humor-18", "humor-06", "humor-04", "humor-16", "humor-20", "humor-13", "humor-02", "humor-14", "humor-03", "humor-09", "humor-21", "humor-15"]
    static let layA: [[Int]] = [[10, 1, 3], [12, 1, 2], [20, 2, 3], [8, 1, 0], [1, 1, 0], [16, 2, 2], [22, 1, 1], [4, 1, 0], [3, 2, 2], [18, 1, 0], [23, 1, 0], [13, 1, 3], [2, 1, 3], [19, 1, 3], [15, 1, 0], [11, 1, 1], [7, 1, 2], [14, 1, 0], [6, 1, 1], [21, 1, 3], [5, 1, 0], [9, 1, 1], [17, 1, 2], [24, 2, 0]]
    static let layB: [[Int]] = [[2, 1, 0], [11, 1, 0], [14, 1, 2], [1, 1, 0], [17, 1, 1], [6, 1, 1], [24, 2, 0], [5, 1, 0], [13, 2, 1], [15, 1, 0], [23, 2, 1], [21, 1, 0], [22, 1, 0], [8, 1, 3], [20, 1, 0], [16, 1, 1], [18, 1, 0], [19, 1, 0], [7, 1, 1], [10, 1, 3], [3, 1, 3], [9, 2, 2], [12, 1, 0], [4, 1, 1]]
}

final class CalendarBuilderTests: XCTestCase {
    private let library = ContentLibrary.bundled

    func testContentIsBundledAndComplete() {
        XCTAssertGreaterThanOrEqual(library.items.count, 352)
        for c in Category.allCases {
            let mine = library.items.filter { $0.category == c }
            XCTAssertGreaterThanOrEqual(mine.filter { $0.budget == .none }.count, 24, c.rawValue)
            XCTAssertGreaterThanOrEqual(mine.filter { $0.budget == .low }.count, 10, c.rawValue)
        }
    }

    func testMatchesWebPick() {
        XCTAssertEqual(CalendarBuilder.pick(categories: [.family, .food], budget: .medium, seed: 12345, library: library), JSVectors.vecA)
        XCTAssertEqual(CalendarBuilder.pick(categories: Category.allCases, budget: .high, seed: 987654321, library: library), JSVectors.vecB)
        XCTAssertEqual(CalendarBuilder.pick(categories: [.humor], budget: .none, seed: 7, library: library), JSVectors.vecC)
    }

    func testMatchesWebLayout() {
        XCTAssertEqual(CalendarBuilder.layout(seed: 12345).map { [$0.day, $0.wide ? 2 : 1, $0.color] }, JSVectors.layA)
        XCTAssertEqual(CalendarBuilder.layout(seed: 2147483646).map { [$0.day, $0.wide ? 2 : 1, $0.color] }, JSVectors.layB)
    }

    func testEveryMixFillsTwentyFourUniqueAllowedDays() {
        let all = Category.allCases
        for mask in 1..<(1 << all.count) {
            let cats = all.enumerated().filter { mask & (1 << $0.offset) != 0 }.map(\.element)
            for budget in Budget.allCases {
                let days = CalendarBuilder.pick(categories: cats, budget: budget, seed: UInt32(mask * 31 + budget.rank), library: library)
                XCTAssertEqual(days.count, 24, "\(cats) \(budget)")
                XCTAssertEqual(Set(days).count, 24, "repeat in \(cats) \(budget)")
                for id in days {
                    let item = library.byID[id]!
                    XCTAssertTrue(cats.contains(item.category))
                    XCTAssertLessThanOrEqual(item.budget.rank, budget.rank)
                }
            }
        }
    }

    func testLayoutPlacesEachDayOnceAndEveIsWide() {
        for seed in stride(from: UInt32(0), to: 400_000, by: 997) {
            let slots = CalendarBuilder.layout(seed: seed)
            XCTAssertEqual(slots.map(\.day).sorted(), Array(1...24))
            XCTAssertTrue(slots.first { $0.day == 24 }!.wide)
            XCTAssertEqual(CalendarBuilder.rows(slots).count, 7)
        }
    }

    func testUnlockByDate() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        func date(_ y: Int, _ m: Int, _ d: Int) -> Date { cal.date(from: DateComponents(year: y, month: m, day: d, hour: 9))! }
        XCTAssertEqual(CalendarBuilder.unlocked(year: 2026, now: date(2026, 11, 30), calendar: cal), 0)
        XCTAssertEqual(CalendarBuilder.unlocked(year: 2026, now: date(2026, 12, 1), calendar: cal), 1)
        XCTAssertEqual(CalendarBuilder.unlocked(year: 2026, now: date(2026, 12, 13), calendar: cal), 13)
        XCTAssertEqual(CalendarBuilder.unlocked(year: 2026, now: date(2026, 12, 30), calendar: cal), 24)
        XCTAssertEqual(CalendarBuilder.unlocked(year: 2026, now: date(2027, 1, 2), calendar: cal), 24)
        XCTAssertEqual(CalendarBuilder.daysToGo(year: 2026, now: date(2026, 11, 20), calendar: cal), 11)
    }

    func testGiftLinkRoundTrips() {
        let days = CalendarBuilder.pick(categories: [.books, .music], budget: .low, seed: 99, library: library)
        let gift = Gift(year: 2026, to: "Zoë", from: "Grandma & Grandpa", note: "One door a day.\nLove you", seed: 99, days: days)
        XCTAssertTrue(gift.url.absoluteString.hasPrefix("https://jackwallner.com/ios/advent/#g="))
        XCTAssertEqual(Gift(url: gift.url, library: library), gift)
    }

    func testOpensLinkMadeByWeb() {
        // Made by the web page: Hazel from Grandma, humor + food, high budget.
        let url = URL(string: "https://jackwallner.com/ios/advent/#g=eyJ5IjoyMDI2LCJ0IjoiSGF6ZWwiLCJmIjoiR3JhbmRtYSIsIm0iOiJPbmUgbGl0dGxlIGRvb3IgYSBkYXkgdW50aWwgQ2hyaXN0bWFzLiBMb3ZlIHlvdSEiLCJsIjo2OTY1NTU5MTcsImQiOiJvMjEuaDIwLm8yMC5oMzcubzQ0Lmg0Mi5vNDMuaDM2Lm8zNC5oMjkubzM2LmgyNy5vMzcuaDI4Lm8xNS5oNDEubzI1LmgxNi5vMjguaDIyLm8yNC5oMzkubzM1LmgyMSJ9")!
        let gift = Gift(url: url, library: library)
        XCTAssertEqual(gift?.to, "Hazel")
        XCTAssertEqual(gift?.from, "Grandma")
        XCTAssertEqual(gift?.days.first, "food-21")
        XCTAssertEqual(gift?.days.count, 24)
    }
}

@MainActor
final class CalendarStoreTests: XCTestCase {
    private func freshDefaults() -> UserDefaults {
        let name = "advent.tests.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    func testCreateOpenRatePersists() {
        let defaults = freshDefaults()
        let store = CalendarStore(library: .bundled, defaults: defaults)
        store.create(categories: [.family, .humor], budget: .low)
        store.open(3)
        store.rate(3, stars: 5)
        let again = CalendarStore(library: .bundled, defaults: defaults)
        XCTAssertEqual(again.mine, store.mine)
        XCTAssertNotNil(again.progress.opened[3])
        XCTAssertEqual(again.progress.ratings[3], 5)
    }

    func testChangeKeepsOpenedDoors() {
        let store = CalendarStore(library: .bundled, defaults: freshDefaults())
        store.create(categories: [.fitness], budget: .none)
        let before = store.mine!.days
        store.open(1)
        store.open(2)
        store.update(categories: [.books, .music], budget: .medium)
        let after = store.mine!.days
        XCTAssertEqual(after[0], before[0])
        XCTAssertEqual(after[1], before[1])
        XCTAssertEqual(Set(after).count, 24)
        XCTAssertTrue(after[2...].allSatisfy { !$0.hasPrefix("fitness") })
    }
}

final class ReviewPromptTrackerTests: XCTestCase {
    func testGates() {
        let name = "advent.review.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        let t = ReviewPromptTracker(defaults: d)
        t.recordLaunch()
        XCTAssertFalse(t.shouldAsk(), "first launch never asks")
        t.recordLaunch()
        XCTAssertTrue(t.shouldAsk())
        let now = Date()
        t.didAsk(now: now)
        XCTAssertFalse(t.shouldAsk(now: now.addingTimeInterval(29 * 86400)))
        XCTAssertTrue(t.shouldAsk(now: now.addingTimeInterval(31 * 86400)))
        t.didOpenWriteReview()
        XCTAssertFalse(t.shouldAsk(now: now.addingTimeInterval(400 * 86400)))
        d.removePersistentDomain(forName: name)
    }
}
