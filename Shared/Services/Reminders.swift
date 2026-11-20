import Foundation
import UserNotifications

/// One local notification each December morning while there are doors left to open.
enum Reminders {
    static let hour = 8
    private static let prefix = "advent.day."

    static func enable(year: Int) async -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        guard granted else { return false }
        await schedule(year: year)
        return true
    }

    static func schedule(year: Int) async {
        let center = UNUserNotificationCenter.current()
        disable()
        let now = Date()
        for day in 1...CalendarBuilder.dayCount {
            var parts = DateComponents(year: year, month: 12, day: day, hour: hour)
            parts.calendar = .current
            guard let fire = parts.date, fire > now else { continue }
            let content = UNMutableNotificationContent()
            content.title = "Door \(day)"
            content.body = day == 24 ? "The last door is ready." : "Today's door is ready."
            content.sound = .default
            let trigger = UNCalendarNotificationTrigger(dateMatching: DateComponents(year: year, month: 12, day: day, hour: hour), repeats: false)
            try? await center.add(UNNotificationRequest(identifier: prefix + "\(day)", content: content, trigger: trigger))
        }
    }

    static func disable() {
        let ids = (1...CalendarBuilder.dayCount).map { prefix + "\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    static func isAuthorized() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
    }
}
