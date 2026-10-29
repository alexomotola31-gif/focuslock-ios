import Foundation
import SwiftUI
import FamilyControls
import DeviceActivity

enum LockError: LocalizedError {
    case notAuthorized, noApps, badSelection
    var errorDescription: String? {
        switch self {
        case .notAuthorized: return "Allow Screen Time access in Setup first."
        case .noApps: return "Choose at least one app or category first."
        case .badSelection: return "Could not read your app selection."
        }
    }
}

enum UnlockResult: Equatable {
    case success
    case wrong(attemptsLeft: Int)
    case cooldown(seconds: Int)
    case dailyLimit
}

final class LockManager: ObservableObject {
    static let shared = LockManager()

    @Published private(set) var timers: [TimerLock] = []
    @Published private(set) var schedules: [ScheduleItem] = []
    @Published private(set) var history: [HistoryEntry] = []
    @Published private(set) var authorized = false
    @Published var syncError: String?
    @Published var dailyGoal: Int = SharedStore.dailyGoalMinutes {
        didSet { SharedStore.dailyGoalMinutes = dailyGoal }
    }
    @Published var defaultSelection = FamilyActivitySelection() {
        didSet {
            if let data = try? JSONEncoder().encode(defaultSelection) {
                SharedStore.defaultSelectionData = data
            }
        }
    }

    private let center = DeviceActivityCenter()
    static let minimumMinutes = 15
    static let dailyEmergencyLimit = 3

    private init() {
        if let data = SharedStore.defaultSelectionData,
           let saved = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) {
            defaultSelection = saved
        }
        reload()
        authorized = AuthorizationCenter.shared.authorizationStatus == .approved
    }

    // MARK: Authorization

    func requestAuthorization() async throws {
        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        await MainActor.run {
            self.authorized = AuthorizationCenter.shared.authorizationStatus == .approved
        }
    }

    // MARK: Refresh

    func reload() {
        timers = SharedStore.timers
        schedules = SharedStore.schedules
        history = SharedStore.history
    }

    /// Called whenever the app becomes active: pick up what the extension did,
    /// finish anything that expired, and make shields match reality.
    func refresh() {
        authorized = AuthorizationCenter.shared.authorizationStatus == .approved
        reload()
        completeExpiredTimers()
        syncScheduleShields()
        reload()
    }

    func completeExpiredTimers() {
        let now = Date()
        var changed = false
        for timer in SharedStore.timers where timer.endTime <= now {
            ShieldApplier.clear(name: "timer.\(timer.id)")
            center.stopMonitoring([DeviceActivityName(rawValue: "timer.\(timer.id)")])
            Notifier.cancelTimerEnd(id: timer.id)
            if SharedStore.finishTimer(id: timer.id, reason: .completed) { changed = true }
        }
        if changed { reload() }
    }

    // MARK: Timers

    /// Starts a strict timer lock. Returns the one-time 6-digit emergency code.
    func startTimer(minutes: Int, pomodoro: Bool, selection: FamilyActivitySelection) throws -> String {
        guard authorized else { throw LockError.notAuthorized }
        guard selection.hasItems else { throw LockError.noApps }
        guard let data = try? JSONEncoder().encode(selection) else { throw LockError.badSelection }

        let cal = Calendar.current
        let now = Date()
        let units: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute]
        let startComps = cal.dateComponents(units, from: now)
        let rawEnd = now.addingTimeInterval(TimeInterval(max(minutes, Self.minimumMinutes) * 60))
        let end = Date(timeIntervalSinceReferenceDate: ceil(rawEnd.timeIntervalSinceReferenceDate / 60) * 60)

        let code = PBKDF2.randomCode()
        let salt = PBKDF2.randomSalt()
        let id = UUID().uuidString
        let lock = TimerLock(
            id: id,
            name: pomodoro ? "Pomodoro" : "Focus \(formatMinutes(max(minutes, Self.minimumMinutes)))",
            selectionData: data,
            appCount: selection.itemCount,
            startedAt: now,
            endTime: end,
            codeHash: PBKDF2.hash(pin: code, salt: salt),
            codeSalt: salt,
            pomodoro: pomodoro
        )

        var list = SharedStore.timers
        list.append(lock)
        SharedStore.timers = list
        ShieldApplier.apply(name: "timer.\(id)", selectionData: data)

        let schedule = DeviceActivitySchedule(
            intervalStart: startComps,
            intervalEnd: cal.dateComponents(units, from: end),
            repeats: false
        )
        do {
            try center.startMonitoring(DeviceActivityName(rawValue: "timer.\(id)"), during: schedule)
            syncError = nil
        } catch {
            syncError = "Background timer could not be registered (\(error.localizedDescription)). The lock will still end when you reopen FocusLock after \(end.formatted(date: .omitted, time: .shortened))."
        }
        Notifier.requestPermission()
        Notifier.scheduleTimerEnd(id: id, end: end, name: lock.name)
        reload()
        return code
    }

    func emergencyUnlock(timer: TimerLock, code: String) -> UnlockResult {
        if SharedStore.emergencyUsesToday >= Self.dailyEmergencyLimit { return .dailyLimit }
        if let until = SharedStore.cooldownUntil, until > Date() {
            return .cooldown(seconds: Int(until.timeIntervalSinceNow.rounded(.up)))
        }
        let ok = PBKDF2.constantTimeEqual(PBKDF2.hash(pin: code, salt: timer.codeSalt), timer.codeHash)
        guard ok else {
            let fails = SharedStore.failedAttempts + 1
            if fails >= 3 {
                SharedStore.failedAttempts = 0
                SharedStore.cooldownUntil = Date().addingTimeInterval(60)
                return .cooldown(seconds: 60)
            }
            SharedStore.failedAttempts = fails
            return .wrong(attemptsLeft: 3 - fails)
        }
        SharedStore.failedAttempts = 0
        SharedStore.recordEmergencyUse()
        ShieldApplier.clear(name: "timer.\(timer.id)")
        center.stopMonitoring([DeviceActivityName(rawValue: "timer.\(timer.id)")])
        Notifier.cancelTimerEnd(id: timer.id)
        SharedStore.finishTimer(id: timer.id, reason: .emergencyUnlock)
        reload()
        return .success
    }

    // MARK: Schedules

    func isLocked(_ item: ScheduleItem) -> Bool { item.isActive() }

    func saveSchedule(_ item: ScheduleItem) {
        var list = SharedStore.schedules
        if let index = list.firstIndex(where: { $0.id == item.id }) {
            guard !list[index].isActive() else { return }   // strict: no edits mid-window
            list[index] = item
        } else {
            list.append(item)
        }
        SharedStore.schedules = list
        reload()
        syncMonitoring(for: item)
        syncScheduleShields()
    }

    func setScheduleEnabled(_ item: ScheduleItem, enabled: Bool) {
        var copy = item
        copy.enabled = enabled
        saveSchedule(copy)
    }

    func deleteSchedule(_ item: ScheduleItem) {
        guard !item.isActive() else { return }              // strict: no deletes mid-window
        stopMonitoring(id: item.id)
        Notifier.cancelWarnings(id: item.id)
        ShieldApplier.clear(name: "schedule.\(item.id)")
        SharedStore.setScheduleStart(nil, id: item.id)
        SharedStore.schedules = SharedStore.schedules.filter { $0.id != item.id }
        reload()
    }

    private func activityNames(_ id: String) -> [DeviceActivityName] {
        (1...7).map { DeviceActivityName(rawValue: "schedule.\(id).\($0)") }
    }

    private func stopMonitoring(id: String) {
        center.stopMonitoring(activityNames(id))
    }

    private func syncMonitoring(for item: ScheduleItem) {
        stopMonitoring(id: item.id)
        Notifier.cancelWarnings(id: item.id)
        guard item.enabled else { return }
        var firstError: String?
        for day in item.weekdays {
            let start = DateComponents(hour: item.startMinute / 60, minute: item.startMinute % 60, weekday: day)
            let endDay = item.endMinute > item.startMinute ? day : (day % 7) + 1
            let end = DateComponents(hour: item.endMinute / 60, minute: item.endMinute % 60, weekday: endDay)
            let schedule = DeviceActivitySchedule(intervalStart: start, intervalEnd: end, repeats: true)
            do {
                try center.startMonitoring(DeviceActivityName(rawValue: "schedule.\(item.id).\(day)"), during: schedule)
            } catch {
                firstError = error.localizedDescription
            }
        }
        syncError = firstError.map { "Schedule \"\(item.name)\" could not be registered: \($0)" }
        if item.warnMinutes > 0 {
            Notifier.requestPermission()
            Notifier.scheduleWarnings(item)
        }
    }

    /// Makes every schedule's shield match whether its window is open right now.
    func syncScheduleShields() {
        for item in SharedStore.schedules {
            let name = "schedule.\(item.id)"
            if item.isActive() {
                if SharedStore.scheduleStart(item.id) == nil {
                    SharedStore.setScheduleStart(Date(), id: item.id)
                }
                ShieldApplier.apply(name: name, selectionData: item.selectionData)
            } else {
                ShieldApplier.clear(name: name)
                SharedStore.finishSchedule(item)
            }
        }
    }

    static func duration(startMinute: Int, endMinute: Int) -> Int {
        endMinute > startMinute ? endMinute - startMinute : endMinute + 1440 - startMinute
    }
}

// MARK: Stats

enum Stats {
    static func minutes(_ entry: HistoryEntry) -> Int {
        max(0, Int(entry.endedAt.timeIntervalSince(entry.startedAt) / 60))
    }

    static func minutes(on day: Date, in history: [HistoryEntry]) -> Int {
        history.filter { Calendar.current.isDate($0.endedAt, inSameDayAs: day) }
            .reduce(0) { $0 + minutes($1) }
    }

    static func lastDays(_ count: Int, in history: [HistoryEntry]) -> [(day: Date, minutes: Int)] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<count).reversed().map { offset in
            let day = cal.date(byAdding: .day, value: -offset, to: today) ?? today
            return (day, minutes(on: day, in: history))
        }
    }

    static func total(_ history: [HistoryEntry]) -> Int {
        history.reduce(0) { $0 + minutes($1) }
    }

    static func streak(in history: [HistoryEntry], goal: Int) -> Int {
        guard goal > 0 else { return 0 }
        let cal = Calendar.current
        var day = cal.startOfDay(for: Date())
        if minutes(on: day, in: history) < goal {
            day = cal.date(byAdding: .day, value: -1, to: day) ?? day
        }
        var count = 0
        while minutes(on: day, in: history) >= goal {
            count += 1
            guard let previous = cal.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }
}
