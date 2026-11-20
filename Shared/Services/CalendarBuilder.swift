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

struct DoorSlot: Equatable, Sendable {
    let day: Int
    let wide: Bool
    let color: Int
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

    /// Seven rows of four cells; four rows hold one double-width door. Day 24 always gets a wide door.
    static func layout(seed: UInt32) -> [DoorSlot] {
        var r = SeededRandom(seed: seed ^ 0x9E37_79B9)
        let wideRows = Set(r.shuffled(Array(0..<7)).prefix(4))
        var widths: [Bool] = []
        for row in 0..<7 {
            if wideRows.contains(row) {
                let at = Int(r.next() * 3)
                for k in 0..<3 { widths.append(k == at) }
            } else {
                widths.append(contentsOf: [false, false, false, false])
            }
        }
        let wideIndexes = widths.indices.filter { widths[$0] }
        let eve = wideIndexes[Int(r.next() * Double(wideIndexes.count))]
        var days = Array(repeating: 0, count: widths.count)
        days[eve] = 24
        var rest = r.shuffled(Array(1...23)).makeIterator()
        for i in days.indices where days[i] == 0 { days[i] = rest.next() ?? 0 }
        return widths.indices.map { i in
            DoorSlot(day: days[i], wide: widths[i], color: (days[i] * 7 + i + Int(seed)) % 4)
        }
    }

    /// Rows for the grid, in display order.
    static func rows(_ slots: [DoorSlot]) -> [[DoorSlot]] {
        var rows: [[DoorSlot]] = []
        var row: [DoorSlot] = []
        var cells = 0
        for s in slots {
            row.append(s)
            cells += s.wide ? 2 : 1
            if cells == 4 {
                rows.append(row)
                row = []
                cells = 0
            }
        }
        return rows
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
