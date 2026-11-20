import Foundation

/// Fleet ratings rules: ask from the second launch on, at a positive moment (a door rated), 30-day cooldown,
/// no enjoyment gate. Only tapping the write-review row stops the passive asks.
struct ReviewPromptTracker {
    static let cooldown: TimeInterval = 30 * 24 * 60 * 60

    private let defaults: UserDefaults
    private enum Keys {
        static let launches = "review.launches"
        static let lastAsk = "review.lastAsk"
        static let wroteReview = "review.wroteReview"
    }

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func recordLaunch() { defaults.set(defaults.integer(forKey: Keys.launches) + 1, forKey: Keys.launches) }

    func shouldAsk(now: Date = Date()) -> Bool {
        guard !defaults.bool(forKey: Keys.wroteReview) else { return false }
        guard defaults.integer(forKey: Keys.launches) >= 2 else { return false }
        if let last = defaults.object(forKey: Keys.lastAsk) as? Date, now.timeIntervalSince(last) < Self.cooldown {
            return false
        }
        return true
    }

    func didAsk(now: Date = Date()) { defaults.set(now, forKey: Keys.lastAsk) }

    func didOpenWriteReview() { defaults.set(true, forKey: Keys.wroteReview) }
}
