import Foundation
import UserNotifications

enum Notifier {
    static func requestPermission(_ done: ((Bool) -> Void)? = nil) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { ok, _ in
            DispatchQueue.main.async { done?(ok) }
        }
    }

    static func checkPermission(_ done: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let ok = settings.authorizationStatus == .authorized
                || settings.authorizationStatus == .provisional
            DispatchQueue.main.async { done(ok) }
        }
    }

    static func scheduleTimerEnd(id: String, end: Date, name: String) {
        let content = UNMutableNotificationContent()
        content.title = "FocusLock session complete"
        content.body = "\(name) has ended. Your apps are unlocked."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(1, end.timeIntervalSinceNow), repeats: false)
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: "end.\(id)", content: content, trigger: trigger))
    }

    static func cancelTimerEnd(id: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["end.\(id)"])
    }

    /// Weekly "locking soon" warnings before each scheduled window.
    static func scheduleWarnings(_ item: ScheduleItem) {
        cancelWarnings(id: item.id)
        guard item.enabled, item.warnMinutes > 0 else { return }
        for day in item.weekdays {
            var total = item.startMinute - item.warnMinutes
            var weekday = day
            if total < 0 {
                total += 1440
                weekday = day == 1 ? 7 : day - 1
            }
            let content = UNMutableNotificationContent()
            content.title = "\(item.name) locks soon"
            content.body = "Your scheduled lock starts in \(item.warnMinutes) minutes."
            content.sound = .default
            let comps = DateComponents(hour: total / 60, minute: total % 60, weekday: weekday)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            UNUserNotificationCenter.current().add(
                UNNotificationRequest(identifier: "warn.\(item.id).\(day)", content: content, trigger: trigger))
        }
    }

    static func cancelWarnings(id: String) {
        let ids = (1...7).map { "warn.\(id).\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }
}
