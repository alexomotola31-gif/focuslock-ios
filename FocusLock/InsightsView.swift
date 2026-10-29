import SwiftUI

struct InsightsView: View {
    @EnvironmentObject var manager: LockManager
    @EnvironmentObject var theme: ThemeStore

    private var week: [(day: Date, minutes: Int)] { Stats.lastDays(7, in: manager.history) }
    private var today: Int { Stats.minutes(on: Date(), in: manager.history) }
    private var streak: Int { Stats.streak(in: manager.history, goal: manager.dailyGoal) }
    private var completed: Int { manager.history.filter { $0.reason == .completed }.count }
    private var emergencies: Int { manager.history.filter { $0.reason == .emergencyUnlock }.count }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    FLCard {
                        Text("Insights").flHeading()
                        HStack {
                            stat("Today", formatMinutes(today))
                            stat("7 days", formatMinutes(week.reduce(0) { $0 + $1.minutes }))
                            stat("All time", formatMinutes(Stats.total(manager.history)))
                        }
                        HStack {
                            stat("Completed", "\(completed)")
                            stat("Emergency", "\(emergencies)")
                            stat("Streak", "\(streak)d")
                        }
                    }

                    FLCard {
                        Text("Last 7 days").flHeading()
                        let peak = max(week.map { $0.minutes }.max() ?? 1, manager.dailyGoal, 1)
                        HStack(alignment: .bottom, spacing: 8) {
                            ForEach(0..<week.count, id: \.self) { index in
                                let entry = week[index]
                                VStack(spacing: 4) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(entry.minutes >= manager.dailyGoal ? theme.accent : theme.accent.opacity(0.4))
                                        .frame(height: max(4, CGFloat(entry.minutes) / CGFloat(peak) * 90))
                                    Text(entry.day.formatted(.dateTime.weekday(.narrow)))
                                        .font(.caption2).foregroundColor(Color.flMuted)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .frame(height: 115, alignment: .bottom)
                    }

                    FLCard {
                        Text("Daily goal").flHeading()
                        Stepper("Goal: \(formatMinutes(manager.dailyGoal))", value: $manager.dailyGoal, in: 15...720, step: 15)
                            .font(.subheadline).foregroundColor(Color.flText)
                        Text("A day counts toward your streak when you reach the goal.").flBody()
                    }

                    FLCard {
                        Text("Achievements").flHeading()
                        ForEach(0..<achievements.count, id: \.self) { index in
                            let item = achievements[index]
                            HStack {
                                Image(systemName: item.done ? "checkmark.seal.fill" : "seal")
                                    .foregroundColor(item.done ? theme.accent : Color.flMuted)
                                Text(item.title).foregroundColor(item.done ? Color.flText : Color.flMuted)
                                    .font(.subheadline)
                            }
                        }
                    }

                    NavigationLink { HistoryView() } label: {
                        Text("View full history")
                    }
                    .buttonStyle(AccentButtonStyle())
                }
                .padding()
            }
            .background(Color.flBackground.ignoresSafeArea())
            .navigationTitle("Progress")
        }
    }

    private var achievements: [(title: String, done: Bool)] {
        [
            ("First completed lock", completed >= 1),
            ("Hit your daily goal", today >= manager.dailyGoal),
            ("3-day streak", streak >= 3),
            ("7-day streak", streak >= 7),
            ("10 hours focused", Stats.total(manager.history) >= 600)
        ]
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(.title3, design: .serif).bold()).foregroundColor(Color.flText)
            Text(label).font(.caption).foregroundColor(Color.flMuted)
        }
        .frame(maxWidth: .infinity)
    }
}

struct HistoryView: View {
    @EnvironmentObject var manager: LockManager
    @EnvironmentObject var theme: ThemeStore

    var body: some View {
        Group {
            if manager.history.isEmpty {
                VStack(spacing: 8) {
                    Text("No sessions yet").flHeading()
                    Text("Completed and emergency-unlocked locks will appear here.").flBody()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(manager.history) { entry in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text("\(entry.kind.rawValue) · \(entry.name)")
                                .font(.system(.subheadline, design: .serif).bold())
                                .foregroundColor(Color.flText)
                            Spacer()
                            Text(entry.reason.rawValue)
                                .font(.caption)
                                .foregroundColor(entry.reason == .emergencyUnlock ? .red : theme.accent)
                        }
                        Text("\(entry.startedAt.formatted(date: .abbreviated, time: .shortened)) → \(entry.endedAt.formatted(date: .omitted, time: .shortened)) · \(formatMinutes(Stats.minutes(entry)))")
                            .flBody()
                    }
                    .listRowBackground(Color.flCard)
                }
                .scrollContentBackground(.hidden)
            }
        }
        .background(Color.flBackground.ignoresSafeArea())
        .navigationTitle("History")
    }
}
