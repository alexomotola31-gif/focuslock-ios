import Foundation
import FamilyControls

enum AppGroup {
    static let id = "group.com.alex.focuslock"
}

enum EndReason: String, Codable {
    case completed = "Completed"
    case emergencyUnlock = "Emergency unlock"
}

enum LockKind: String, Codable {
    case timer = "Timer"
    case schedule = "Schedule"
}

/// A running timer lock. Several can run at once; each owns its own
/// ManagedSettings store ("timer.<id>") so the OS merges the shields.
struct TimerLock: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var selectionData: Data
    var appCount: Int
    var startedAt: Date
    var endTime: Date
    var codeHash: Data
    var codeSalt: Data
    var pomodoro: Bool
}

/// A recurring, fully strict lock window. weekdays use Calendar numbering
/// (1 = Sunday ... 7 = Saturday). Minutes are minutes since midnight.
struct ScheduleItem: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var weekdays: [Int]
    var startMinute: Int
    var endMinute: Int
    var enabled: Bool
    var selectionData: Data
    var appCount: Int
    var warnMinutes: Int

    var durationMinutes: Int {
        endMinute > startMinute ? endMinute - startMinute : endMinute + 1440 - startMinute
    }

    func isActive(at date: Date = Date()) -> Bool {
        guard enabled else { return false }
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: date)
        let minute = cal.component(.hour, from: date) * 60 + cal.component(.minute, from: date)
        if endMinute > startMinute {
            return weekdays.contains(weekday) && minute >= startMinute && minute < endMinute
        }
        let previous = weekday == 1 ? 7 : weekday - 1
        return (weekdays.contains(weekday) && minute >= startMinute)
            || (weekdays.contains(previous) && minute < endMinute)
    }

    /// Next time this window ends (only meaningful while active).
    func currentEnd(from date: Date = Date()) -> Date? {
        let cal = Calendar.current
        let comps = DateComponents(hour: endMinute / 60, minute: endMinute % 60, second: 0)
        return cal.nextDate(after: date, matching: comps, matchingPolicy: .nextTime)
    }
}

struct HistoryEntry: Codable, Identifiable {
    var id: String
    var kind: LockKind
    var name: String
    var startedAt: Date
    var endedAt: Date
    var reason: EndReason
    var appCount: Int
}

extension FamilyActivitySelection {
    var hasItems: Bool {
        !applicationTokens.isEmpty || !categoryTokens.isEmpty || !webDomainTokens.isEmpty
    }
    var itemCount: Int {
        applicationTokens.count + categoryTokens.count + webDomainTokens.count
    }
}
