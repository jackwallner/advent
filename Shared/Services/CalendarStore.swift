import Foundation
import Observation

struct SavedCalendar: Codable, Equatable, Sendable {
    var year: Int
    var categories: [Category]
    var budget: Budget
    var seed: UInt32
    var days: [String]
    /// Which house the calendar lives in. Optional so calendars saved before houses still load.
    var theme: Int?
}

struct Progress: Codable, Equatable, Sendable {
    var opened: [Int: Date] = [:]
    var ratings: [Int: Int] = [:]
    /// Days whose first rating has already steered the doors ahead.
    var steered: [Int]?
}

@MainActor
@Observable
final class CalendarStore {
    let library: ContentLibrary
    private let defaults: UserDefaults

    private(set) var mine: SavedCalendar?
    private(set) var progress = Progress()
    /// Bumped when the app comes to the foreground so a new day unlocks without a relaunch.
    var now = Date()
    /// Debug builds only: pretend this many doors are unlocked.
    var debugDay: Int? {
        didSet { defaults.set(debugDay ?? -1, forKey: Keys.debugDay) }
    }

    private enum Keys {
        static let mine = "advent.mine"
        static let progress = "advent.progress"
        static let debugDay = "advent.debugDay"
    }

    init(library: ContentLibrary = .bundled, defaults: UserDefaults = .standard) {
        self.library = library
        self.defaults = defaults
        mine = Self.load(SavedCalendar.self, defaults, Keys.mine)
        progress = Self.load(Progress.self, defaults, Keys.progress) ?? Progress()
        #if DEBUG
        let stored = defaults.object(forKey: Keys.debugDay) as? Int ?? -1
        debugDay = stored >= 0 ? stored : nil
        #endif
    }

    var unlocked: Int {
        guard let mine else { return 0 }
        return unlocked(year: mine.year)
    }

    func unlocked(year: Int) -> Int {
        #if DEBUG
        if let debugDay { return min(max(debugDay, 0), CalendarBuilder.dayCount) }
        #endif
        return CalendarBuilder.unlocked(year: year, now: now)
    }

    func daysToGo(year: Int) -> Int { CalendarBuilder.daysToGo(year: year, now: now) }

    func item(_ id: String) -> Item? { library.byID[id] }

    func create(categories: [Category], budget: Budget, theme: Int = 0) {
        let seed = CalendarBuilder.newSeed()
        let days = CalendarBuilder.pick(categories: categories, budget: budget, seed: seed, library: library)
        let year = Calendar.current.component(.year, from: now)
        mine = SavedCalendar(year: year, categories: categories, budget: budget, seed: seed, days: days, theme: theme)
        progress = Progress()
        save()
    }

    /// Changes what's inside. Doors already opened keep their items; the rest are picked again.
    func update(categories: [Category], budget: Budget, theme: Int = 0) {
        guard var cal = mine else { return create(categories: categories, budget: budget, theme: theme) }
        let keep = Set(progress.opened.keys.compactMap { day in cal.days.indices.contains(day - 1) ? cal.days[day - 1] : nil })
        var fresh = CalendarBuilder.pick(
            categories: categories, budget: budget, seed: CalendarBuilder.newSeed(), excluding: keep, library: library
        ).makeIterator()
        cal.days = cal.days.enumerated().map { i, id in progress.opened[i + 1] != nil ? id : (fresh.next() ?? id) }
        cal.categories = categories
        cal.budget = budget
        cal.theme = theme
        mine = cal
        save()
    }

    func open(_ day: Int) {
        guard progress.opened[day] == nil else { return }
        progress.opened[day] = now
        save()
    }

    /// The first rating of a day also steers what waits behind the doors still locked.
    func rate(_ day: Int, stars: Int) {
        progress.ratings[day] = stars
        if var cal = mine, !(progress.steered ?? []).contains(day) {
            progress.steered = (progress.steered ?? []) + [day]
            if let next = CalendarBuilder.steer(
                days: cal.days, categories: cal.categories, seed: cal.seed, opened: Set(progress.opened.keys),
                day: day, stars: stars, unlocked: unlocked, library: library
            ) {
                cal.days = next
                mine = cal
            }
        }
        save()
    }

    func makeGift(categories: [Category], budget: Budget, theme: Int = 0, to: String, from: String, note: String) -> Gift {
        let seed = CalendarBuilder.newSeed()
        let days = CalendarBuilder.pick(categories: categories, budget: budget, seed: seed, library: library)
        let year = Calendar.current.component(.year, from: now)
        return Gift(year: year, to: to, from: from, note: note, seed: seed, days: days, theme: theme)
    }

    func reset() {
        mine = nil
        progress = Progress()
        defaults.removeObject(forKey: Keys.mine)
        defaults.removeObject(forKey: Keys.progress)
    }

    private func save() {
        if let mine, let data = try? JSONEncoder().encode(mine) { defaults.set(data, forKey: Keys.mine) }
        if let data = try? JSONEncoder().encode(progress) { defaults.set(data, forKey: Keys.progress) }
    }

    private static func load<T: Decodable>(_ type: T.Type, _ defaults: UserDefaults, _ key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
