import SwiftUI
import FamilyControls

struct RevealedCode: Identifiable {
    let id = UUID()
    let code: String
    let minutes: Int
}

struct HomeView: View {
    @EnvironmentObject var manager: LockManager
    @EnvironmentObject var theme: ThemeStore

    @State private var now = Date()
    @State private var minutes = 60
    @State private var pomodoro = false
    @State private var showPicker = false
    @State private var revealed: RevealedCode?
    @State private var emergencyTimer: TimerLock?
    @State private var errorText: String?

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let presets = [15, 30, 60, 120, 240, 480, 1440]

    private var todayMinutes: Int { Stats.minutes(on: Date(), in: manager.history) }
    private var activeSchedules: [ScheduleItem] { manager.schedules.filter { $0.isActive(at: now) } }
    private var canStart: Bool { manager.authorized && manager.defaultSelection.hasItems }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if !manager.authorized { authBanner }
                    dashboard
                    if !manager.timers.isEmpty || !activeSchedules.isEmpty { activeLocks }
                    startCard
                    if let text = manager.syncError {
                        Text(text).font(.footnote).foregroundColor(.orange)
                    }
                }
                .padding()
            }
            .background(Color.flBackground.ignoresSafeArea())
            .navigationTitle("FocusLock")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink { HistoryView() } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                }
            }
        }
        .onReceive(ticker) { tick in
            now = tick
            manager.completeExpiredTimers()
        }
        .familyActivityPicker(isPresented: $showPicker, selection: $manager.defaultSelection)
        .sheet(item: $revealed) { item in
            CodeRevealView(code: item.code, minutes: item.minutes)
                .interactiveDismissDisabled(true)
        }
        .sheet(item: $emergencyTimer) { timer in
            EmergencyUnlockView(timer: timer)
        }
    }

    private var authBanner: some View {
        FLCard {
            Text("Screen Time access needed").flHeading()
            Text("Without it iOS can't shield apps — and if it's revoked during a lock, the lock ends. Open Setup to allow it.")
                .flBody()
        }
    }

    private var dashboard: some View {
        FLCard {
            HStack(spacing: 18) {
                ProgressRing(
                    progress: Double(todayMinutes) / Double(max(manager.dailyGoal, 1)),
                    title: formatMinutes(todayMinutes),
                    subtitle: "of \(formatMinutes(manager.dailyGoal))"
                )
                VStack(alignment: .leading, spacing: 6) {
                    Text("Today").flHeading()
                    Text("Streak: \(Stats.streak(in: manager.history, goal: manager.dailyGoal)) day(s)").flBody()
                    Text("\(manager.history.count) session(s) logged").flBody()
                }
            }
        }
    }

    private var activeLocks: some View {
        FLCard {
            Text("Active locks").flHeading()
            ForEach(manager.timers) { timer in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(timer.name).font(.system(.subheadline, design: .serif).bold())
                            .foregroundColor(Color.flText)
                        Spacer()
                        Text(formatClock(timer.endTime.timeIntervalSince(now)))
                            .font(.system(.title3, design: .monospaced).bold())
                            .foregroundColor(theme.accent)
                    }
                    Text("\(timer.appCount) item(s) · ends \(timer.endTime.formatted(date: .omitted, time: .shortened))")
                        .flBody()
                    Button("Emergency code") { emergencyTimer = timer }
                        .buttonStyle(AccentButtonStyle())
                }
                Divider()
            }
            ForEach(activeSchedules) { item in
                HStack {
                    Image(systemName: "lock.fill").foregroundColor(theme.accent)
                    VStack(alignment: .leading) {
                        Text(item.name).font(.system(.subheadline, design: .serif).bold())
                            .foregroundColor(Color.flText)
                        Text("Strict schedule · until \(clockString(minuteOfDay: item.endMinute)) · no early exit")
                            .flBody()
                    }
                }
            }
        }
    }

    private var startCard: some View {
        FLCard {
            Text("New timer lock").flHeading()
            Text(manager.defaultSelection.hasItems
                 ? "\(manager.defaultSelection.itemCount) app(s)/categories selected"
                 : "No apps selected yet")
                .flBody()
            Button(manager.defaultSelection.hasItems ? "Change apps" : "Choose apps") { showPicker = true }
                .buttonStyle(AccentButtonStyle())

            Toggle("Pomodoro (25 min focus block)", isOn: $pomodoro)
                .font(.subheadline).foregroundColor(Color.flText)

            if !pomodoro {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                    ForEach(presets, id: \.self) { preset in
                        Button(formatMinutes(preset)) { minutes = preset }
                            .buttonStyle(AccentButtonStyle())
                            .opacity(minutes == preset ? 1.0 : 0.5)
                    }
                }
                Stepper("Custom: \(formatMinutes(minutes))", value: $minutes, in: 15...1440, step: 15)
                    .font(.subheadline).foregroundColor(Color.flText)
            }

            Text("Minimum 15 minutes. You get a one-time emergency code when it starts — it can end this timer early (3 uses per day). Nothing else can.")
                .flBody()
            if let errorText = errorText { Text(errorText).font(.footnote).foregroundColor(.red) }

            Button("Start focus lock") { start() }
                .buttonStyle(AccentButtonStyle())
                .disabled(!canStart)
        }
    }

    private func start() {
        let length = pomodoro ? 25 : minutes
        do {
            let code = try manager.startTimer(minutes: length, pomodoro: pomodoro, selection: manager.defaultSelection)
            errorText = nil
            revealed = RevealedCode(code: code, minutes: length)
        } catch {
            errorText = error.localizedDescription
        }
    }
}

struct CodeRevealView: View {
    @EnvironmentObject var theme: ThemeStore
    @Environment(\.dismiss) private var dismiss
    let code: String
    let minutes: Int
    @State private var saved = false

    var body: some View {
        VStack(spacing: 18) {
            Text("Locked for \(formatMinutes(minutes))")
                .font(.system(.title2, design: .serif).bold())
                .foregroundColor(theme.accent)
            Text("Your emergency code").flBody()
            Text(code)
                .font(.system(size: 46, weight: .bold, design: .monospaced))
                .foregroundColor(Color.flText)
                .textSelection(.enabled)
            Text("This is shown once and can't be recovered. It ends this timer only, and works at most 3 times per day. If you don't want an exit, don't write it down.")
                .flBody()
                .multilineTextAlignment(.center)
            Toggle("I've saved or dismissed it", isOn: $saved)
                .font(.subheadline).foregroundColor(Color.flText)
            Button("Done") { dismiss() }
                .buttonStyle(AccentButtonStyle())
                .disabled(!saved)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.flBackground.ignoresSafeArea())
    }
}

struct EmergencyUnlockView: View {
    @EnvironmentObject var manager: LockManager
    @EnvironmentObject var theme: ThemeStore
    @Environment(\.dismiss) private var dismiss
    let timer: TimerLock
    @State private var code = ""
    @State private var message: String?

    var body: some View {
        VStack(spacing: 16) {
            Text("Emergency unlock")
                .font(.system(.title3, design: .serif).bold())
                .foregroundColor(theme.accent)
            Text("Enter the 6-digit code you were given when \(timer.name) started. Uses today: \(SharedStore.emergencyUsesToday) of \(LockManager.dailyEmergencyLimit).")
                .flBody()
                .multilineTextAlignment(.center)
            SecureField("6-digit code", text: $code)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
            if let message = message { Text(message).font(.footnote).foregroundColor(.red) }
            Button("Unlock") { attempt() }
                .buttonStyle(AccentButtonStyle())
                .disabled(code.count != 6)
            Button("Cancel") { dismiss() }.foregroundColor(Color.flMuted)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.flBackground.ignoresSafeArea())
        .presentationDetents([.medium])
    }

    private func attempt() {
        switch manager.emergencyUnlock(timer: timer, code: code) {
        case .success: dismiss()
        case .wrong(let left):
            message = "Wrong code. \(left) attempt(s) left before a 60-second cooldown."
        case .cooldown(let seconds):
            message = "Too many wrong attempts. Try again in \(seconds)s."
        case .dailyLimit:
            message = "You've used all 3 emergency unlocks for today."
        }
        code = ""
    }
}
