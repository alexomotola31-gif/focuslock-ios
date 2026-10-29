import AppIntents

struct StartFocusLockIntent: AppIntent {
    static var title: LocalizedStringResource = "Start focus lock"
    static var description = IntentDescription("Locks the apps chosen in FocusLock for a set time.")

    @Parameter(title: "Minutes", default: 30)
    var minutes: Int

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let manager = LockManager.shared
        manager.refresh()
        guard manager.authorized else {
            return .result(dialog: "FocusLock needs Screen Time access. Open the app and allow it first.")
        }
        let length = max(LockManager.minimumMinutes, minutes)
        do {
            let code = try manager.startTimer(minutes: length, pomodoro: false, selection: manager.defaultSelection)
            return .result(dialog: "Locked for \(length) minutes. Emergency code: \(code)")
        } catch {
            return .result(dialog: "\(error.localizedDescription)")
        }
    }
}

struct FocusLockShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartFocusLockIntent(),
            phrases: ["Start a lock in \(.applicationName)"],
            shortTitle: "Start focus lock",
            systemImageName: "lock.fill"
        )
    }
}
