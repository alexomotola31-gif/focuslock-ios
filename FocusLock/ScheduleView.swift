import SwiftUI
import FamilyControls

struct ScheduleView: View {
    @EnvironmentObject var manager: LockManager
    @EnvironmentObject var theme: ThemeStore
    @State private var editing: ScheduleItem?
    @State private var creating = false

    var body: some View {
        NavigationStack {
            List {
                if manager.schedules.isEmpty {
                    Text("No schedules yet. Add one — e.g. 7–10 PM on weekdays. Schedules can overlap and run at the same time.")
                        .flBody()
                }
                ForEach(manager.schedules) { item in
                    row(item)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.flBackground.ignoresSafeArea())
            .navigationTitle("Schedule")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { creating = true } label: { Image(systemName: "plus") }
                }
            }
        }
        .sheet(isPresented: $creating) {
            ScheduleEditor(existing: nil)
        }
        .sheet(item: $editing) { item in
            ScheduleEditor(existing: item)
        }
    }

    private func row(_ item: ScheduleItem) -> some View {
        let locked = item.isActive()
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(item.name).font(.system(.headline, design: .serif)).foregroundColor(Color.flText)
                Spacer()
                if locked {
                    Label("Locked", systemImage: "lock.fill").font(.caption).foregroundColor(theme.accent)
                } else {
                    Toggle("", isOn: Binding(
                        get: { item.enabled },
                        set: { manager.setScheduleEnabled(item, enabled: $0) }
                    )).labelsHidden()
                }
            }
            Text("\(clockString(minuteOfDay: item.startMinute)) – \(clockString(minuteOfDay: item.endMinute)) · \(dayLabel(item.weekdays))")
                .flBody()
            Text("\(item.appCount) item(s)\(item.warnMinutes > 0 ? " · warns \(item.warnMinutes)m before" : "")")
                .flBody()
            if locked {
                Text("Strict: can't be edited, disabled or deleted until the window ends.")
                    .font(.caption).foregroundColor(theme.accent)
            } else {
                HStack {
                    Button("Edit") { editing = item }.buttonStyle(.borderless)
                    Spacer()
                    Button("Delete", role: .destructive) { manager.deleteSchedule(item) }.buttonStyle(.borderless)
                }
            }
        }
        .padding(.vertical, 4)
        .listRowBackground(Color.flCard)
    }

    private func dayLabel(_ days: [Int]) -> String {
        if days.count == 7 { return "Every day" }
        let names = ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return days.sorted().map { names[$0] }.joined(separator: " ")
    }
}

struct ScheduleEditor: View {
    @EnvironmentObject var manager: LockManager
    @EnvironmentObject var theme: ThemeStore
    @Environment(\.dismiss) private var dismiss

    let existing: ScheduleItem?
    @State private var name = ""
    @State private var days: Set<Int> = [2, 3, 4, 5, 6]
    @State private var start = Date()
    @State private var end = Date()
    @State private var warn = 5
    @State private var selection = FamilyActivitySelection()
    @State private var showPicker = false
    @State private var error: String?
    @State private var loaded = false

    private let letters = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") { TextField("Evening focus", text: $name) }
                Section("Days") {
                    HStack {
                        ForEach(1...7, id: \.self) { day in
                            Text(letters[day - 1])
                                .font(.subheadline.bold())
                                .frame(width: 36, height: 36)
                                .background(Circle().fill(days.contains(day) ? theme.accent : Color.flMuted.opacity(0.2)))
                                .foregroundColor(days.contains(day) ? Color.flInk : Color.flText)
                                .onTapGesture {
                                    if days.contains(day) { days.remove(day) } else { days.insert(day) }
                                }
                        }
                    }
                }
                Section("Time") {
                    DatePicker("Start", selection: $start, displayedComponents: .hourAndMinute)
                    DatePicker("End", selection: $end, displayedComponents: .hourAndMinute)
                    Picker("Warn before", selection: $warn) {
                        Text("Off").tag(0)
                        Text("5 min").tag(5)
                        Text("10 min").tag(10)
                        Text("15 min").tag(15)
                    }
                }
                Section("Apps") {
                    Text(selection.hasItems ? "\(selection.itemCount) item(s) selected" : "None selected")
                    Button("Choose apps & categories") { showPicker = true }
                }
                Section {
                    Text("Scheduled locks are fully strict: no emergency code, no early removal. Window must be at least 15 minutes.")
                        .flBody()
                    if let error = error { Text(error).font(.footnote).foregroundColor(.red) }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.flBackground.ignoresSafeArea())
            .navigationTitle(existing == nil ? "New schedule" : "Edit schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() } }
            }
        }
        .familyActivityPicker(isPresented: $showPicker, selection: $selection)
        .onAppear { load() }
    }

    private func minuteOfDay(_ date: Date) -> Int {
        let cal = Calendar.current
        return cal.component(.hour, from: date) * 60 + cal.component(.minute, from: date)
    }

    private func date(for minute: Int) -> Date {
        Calendar.current.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: Date()) ?? Date()
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        if let item = existing {
            name = item.name
            days = Set(item.weekdays)
            start = date(for: item.startMinute)
            end = date(for: item.endMinute)
            warn = item.warnMinutes
            if let saved = try? JSONDecoder().decode(FamilyActivitySelection.self, from: item.selectionData) {
                selection = saved
            }
        } else {
            start = date(for: 19 * 60)
            end = date(for: 22 * 60)
            selection = manager.defaultSelection
        }
    }

    private func save() {
        let startMinute = minuteOfDay(start)
        let endMinute = minuteOfDay(end)
        guard !days.isEmpty else { error = "Pick at least one day."; return }
        guard selection.hasItems else { error = "Choose at least one app or category."; return }
        guard startMinute != endMinute,
              LockManager.duration(startMinute: startMinute, endMinute: endMinute) >= LockManager.minimumMinutes
        else { error = "Window must be at least 15 minutes."; return }
        guard let data = try? JSONEncoder().encode(selection) else { error = "Could not save app selection."; return }

        let item = ScheduleItem(
            id: existing?.id ?? UUID().uuidString,
            name: name.isEmpty ? "Schedule" : name,
            weekdays: days.sorted(),
            startMinute: startMinute,
            endMinute: endMinute,
            enabled: existing?.enabled ?? true,
            selectionData: data,
            appCount: selection.itemCount,
            warnMinutes: warn
        )
        manager.saveSchedule(item)
        dismiss()
    }
}
