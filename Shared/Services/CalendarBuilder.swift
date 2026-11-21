import Foundation

/// Port of docs/calendar.js. The same seed must give the same days and layout on iOS and the web,
/// because a gift made in the app is opened in a browser. AdventTests pins this with vectors from the JS.
struct SeededRandom {
    private var state: UInt32

    init(seed: UInt32) { state = seed }

    mutating func next() -> Double {
        state = state &+ 0x6D2B_79F5
        var t = state
        t = (t ^ (t >> 15)) &* (t | 1)
        t ^= t &+ ((t ^ (t >> 7)) &* (t | 61))
        return Double(t ^ (t >> 14)) / 4_294_967_296
    }

    mutating func shuffled<T>(_ input: [T]) -> [T] {
        var a = input
        guard a.count > 1 else { return a }
        for i in stride(from: a.count - 1, to: 0, by: -1) {
            let j = Int(next() * Double(i + 1))
            a.swapAt(i, j)
        }
        return a
    }
}

enum CalendarBuilder {
    static let dayCount = 24

    static func quota(_ budget: Budget) -> [Budget: Int] {
        switch budget {
        case .none: [:]
        case .low: [.low: 10]
        case .medium: [.medium: 6, .low: 8]
        case .high: [.high: 4, .medium: 6, .low: 6]
        }
    }

    static func newSeed() -> UInt32 { UInt32.random(in: 0..<2_147_483_647) }

    /// Picks 24 item ids for the chosen categories and budget. `categories` is kept in `Category.allCases` order.
    static func pick(
        categories: [Category],
        budget: Budget,
        seed: UInt32,
        excluding exclude: Set<String> = [],
        library: ContentLibrary
    ) -> [String] {
        let cats = Category.allCases.filter(categories.contains)
        var r = SeededRandom(seed: seed)
        let allowed = Budget.allCases.filter { $0.rank <= budget.rank }
        var pool: [Budget: [Category: [Item]]] = [:]
        for tier in allowed {
            var byCat: [Category: [Item]] = [:]
            for c in cats {
                let matching = library.items.filter { $0.category == c && $0.budget == tier && !exclude.contains($0.id) }
                byCat[c] = r.shuffled(matching)
            }
            pool[tier] = byCat
        }
        var chosen: [Item] = []

        func take(_ tier: Budget, _ count: Int) -> Int {
            guard pool[tier] != nil else { return count }
            var n = count
            let order = r.shuffled(cats)
            while true {
                var moved = false
                for c in order {
                    if n <= 0 { return 0 }
                    if let item = pool[tier]?[c]?.popLast() {
                        chosen.append(item)
                        n -= 1
                        moved = true
                    }
                }
                if !moved || n <= 0 { return n }
            }
        }

        let q = quota(budget)
        for tier in [Budget.high, .medium, .low] {
            if let n = q[tier], n > 0 { _ = take(tier, n) }
        }
        var need = take(.none, dayCount - chosen.count)
        for tier in [Budget.low, .medium, .high] where need > 0 {
            need = take(tier, need)
        }
        return arrange(chosen, &r).map(\.id)
    }

    /// Spreads categories so the same one rarely lands on back-to-back days.
    private static func arrange(_ items: [Item], _ r: inout SeededRandom) -> [Item] {
        var a = r.shuffled(items)
        guard a.count > 1 else { return a }
        for i in 1..<a.count where a[i].category == a[i - 1].category {
            for j in (i + 1)..<max(i + 1, a.count) where a[j].category != a[i - 1].category {
                a.swapAt(i, j)
                break
            }
        }
        return a
    }

    /// The house front. Slot 0 is the attic window, 1 to 20 are four windows on each of five floors,
    /// 21 and 23 the ground floor windows, 22 the front door. Day 24 is always the front door.
    static let frontDoor = 22

    static func layout(seed: UInt32) -> [Int] {
        var r = SeededRandom(seed: seed ^ 0x9E37_79B9)
        var days = r.shuffled(Array(1...23))
        days.insert(24, at: frontDoor)
        return days
    }

    /// Ratings steer the doors that cannot be opened yet. A loved day brings one more of its kind,
    /// a disliked one swaps the next of its kind away. Returns the new days, or nil when nothing changes.
    static func steer(
        days current: [String],
        categories: [Category],
        seed: UInt32,
        opened: Set<Int>,
        day: Int,
        stars: Int,
        unlocked: Int,
        library: ContentLibrary
    ) -> [String]? {
        guard stars != 3, categories.count > 1, current.indices.contains(day - 1),
              let rated = library.byID[current[day - 1]] else { return nil }
        var days = current
        let used = Set(days)
        var r = SeededRandom(seed: seed ^ (UInt32(truncatingIfNeeded: day) &* 2_654_435_761))
        let future = (unlocked + 1...dayCount + 1).filter { $0 <= dayCount && !opened.contains($0) }
        func category(_ d: Int) -> Category? { library.byID[days[d - 1]]?.category }
        func fresh(_ cat: Category, _ tier: Budget) -> Item? {
            r.shuffled(library.items.filter { $0.category == cat && $0.budget == tier && !used.contains($0.id) }).first
        }
        if stars >= 4 {
            var count: [Category: Int] = [:]
            for d in future { if let c = category(d), c != rated.category { count[c, default: 0] += 1 } }
            guard let top = count.keys.sorted(by: { (count[$0]!, $1.rawValue) > (count[$1]!, $0.rawValue) }).first,
                  let d = future.first(where: { category($0) == top }),
                  let tier = library.byID[days[d - 1]]?.budget,
                  let item = fresh(rated.category, tier) else { return nil }
            days[d - 1] = item.id
            return days
        }
        guard let d = future.first(where: { category($0) == rated.category }),
              let tier = library.byID[days[d - 1]]?.budget else { return nil }
        for c in r.shuffled(categories.filter { $0 != rated.category }) {
            if let item = fresh(c, tier) {
                days[d - 1] = item.id
                return days
            }
        }
        return nil
    }

    /// How many doors may be open: 0 before December 1 of `year`, the date through the 24th, then all 24.
    static func unlocked(year: Int, now: Date, calendar: Calendar = .current) -> Int {
        let c = calendar.dateComponents([.year, .month, .day], from: now)
        guard let y = c.year, let m = c.month, let d = c.day else { return 0 }
        if y < year { return 0 }
        if y > year { return dayCount }
        if m < 12 { return 0 }
        return min(d, dayCount)
    }

    static func daysToGo(year: Int, now: Date, calendar: Calendar = .current) -> Int {
        let start = calendar.startOfDay(for: now)
        guard let dec1 = calendar.date(from: DateComponents(year: year, month: 12, day: 1)) else { return 0 }
        return calendar.dateComponents([.day], from: start, to: dec1).day ?? 0
    }
}
