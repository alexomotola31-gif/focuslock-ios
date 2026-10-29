import Foundation

/// Everything the app and the DeviceActivityMonitor extension both need
/// lives in the App Group's UserDefaults.
enum SharedStore {
    private static var defaults: UserDefaults {
        UserDefaults(suiteName: AppGroup.id) ?? .standard
    }

    private static func read<T: Decodable>(_ key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private static func write<T: Encodable>(_ value: T, _ key: String) {
        defaults.set(try? JSONEncoder().encode(value), forKey: key)
    }

    static var timers: [TimerLock] {
        get { read("fl.timers") ?? [] }
        set { write(newValue, "fl.timers") }
    }

    static var schedules: [ScheduleItem] {
        get { read("fl.schedules") ?? [] }
        set { write(newValue, "fl.schedules") }
    }

    static var history: [HistoryEntry] {
        get { read("fl.history") ?? [] }
        set { write(newValue, "fl.history") }
    }

    static var defaultSelectionData: Data? {
        get { defaults.data(forKey: "fl.defaultSelection") }
        set { defaults.set(newValue, forKey: "fl.defaultSelection") }
    }

    static var dailyGoalMinutes: Int {
        get {
            let value = defaults.integer(forKey: "fl.goal")
            return value == 0 ? 120 : value
        }
        set { defaults.set(newValue, forKey: "fl.goal") }
    }

    // MARK: Emergency code limits (3 uses per day, cooldown on failures)

    private static func dayKey(_ date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    static var emergencyUsesToday: Int {
        defaults.string(forKey: "fl.emDay") == dayKey() ? defaults.integer(forKey: "fl.emCount") : 0
    }

    static func recordEmergencyUse() {
        defaults.set(dayKey(), forKey: "fl.emDay")
        defaults.set(emergencyUsesToday + 1, forKey: "fl.emCount")
    }

    static var failedAttempts: Int {
        get { defaults.integer(forKey: "fl.fails") }
        set { defaults.set(newValue, forKey: "fl.fails") }
    }

    static var cooldownUntil: Date? {
        get { defaults.object(forKey: "fl.cooldown") as? Date }
        set { defaults.set(newValue, forKey: "fl.cooldown") }
    }

    // MARK: History helpers (used by both app and extension)

    static func appendHistory(_ entry: HistoryEntry) {
        var list = history
        list.insert(entry, at: 0)
        if list.count > 500 { list = Array(list.prefix(500)) }
        history = list
    }

    static func scheduleStart(_ id: String) -> Date? {
        defaults.object(forKey: "fl.schedStart.\(id)") as? Date
    }

    static func setScheduleStart(_ date: Date?, id: String) {
        defaults.set(date, forKey: "fl.schedStart.\(id)")
    }

    /// Logs a finished schedule window exactly once (start marker is consumed).
    static func finishSchedule(_ item: ScheduleItem, at end: Date = Date()) {
        guard let start = scheduleStart(item.id) else { return }
        appendHistory(HistoryEntry(
            id: UUID().uuidString, kind: .schedule, name: item.name,
            startedAt: start, endedAt: end, reason: .completed, appCount: item.appCount
        ))
        setScheduleStart(nil, id: item.id)
    }

    /// Removes a timer and logs it. Returns false if it was already finished
    /// (so the app and extension never log the same timer twice).
    @discardableResult
    static func finishTimer(id: String, reason: EndReason, at end: Date = Date()) -> Bool {
        var list = timers
        guard let index = list.firstIndex(where: { $0.id == id }) else { return false }
        let timer = list.remove(at: index)
        timers = list
        appendHistory(HistoryEntry(
            id: UUID().uuidString, kind: .timer, name: timer.name,
            startedAt: timer.startedAt,
            endedAt: reason == .completed ? timer.endTime : end,
            reason: reason, appCount: timer.appCount
        ))
        return true
    }
}
