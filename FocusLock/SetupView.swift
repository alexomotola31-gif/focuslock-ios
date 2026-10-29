import SwiftUI
import UIKit

struct SetupView: View {
    @EnvironmentObject var manager: LockManager
    @EnvironmentObject var theme: ThemeStore
    @State private var notificationsOK = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    FLCard {
                        Text("Setup checklist").flHeading()
                        checkRow("Screen Time access", manager.authorized)
                        if !manager.authorized {
                            Button("Allow Screen Time access") {
                                Task { @MainActor in
                                    do {
                                        try await manager.requestAuthorization()
                                        message = nil
                                    } catch {
                                        message = "Not granted: \(error.localizedDescription)"
                                    }
                                }
                            }
                            .buttonStyle(AccentButtonStyle())
                            if let message = message { Text(message).font(.footnote).foregroundColor(.red) }
                            Button("Open iOS Settings") { openSettings() }.buttonStyle(.borderless)
                        }
                        checkRow("Notifications (end of lock, warnings)", notificationsOK)
                        if !notificationsOK {
                            Button("Allow notifications") {
                                Notifier.requestPermission { notificationsOK = $0 }
                            }
                            .buttonStyle(AccentButtonStyle())
                        }
                        checkRow("Apps chosen", manager.defaultSelection.hasItems)
                    }

                    FLCard {
                        Text("Appearance").flHeading()
                        Picker("Mode", selection: $theme.mode) {
                            ForEach(ThemeMode.allCases) { Text($0.title).tag($0) }
                        }.pickerStyle(.segmented)
                        HStack(spacing: 12) {
                            ForEach(AccentChoice.allCases) { choice in
                                Circle().fill(choice.color)
                                    .frame(width: 34, height: 34)
                                    .overlay(Circle().stroke(Color.flText, lineWidth: theme.accentChoice == choice ? 3 : 0))
                                    .onTapGesture { theme.accentChoice = choice }
                            }
                        }
                        Picker("Text size", selection: $theme.textSize) {
                            ForEach(TextSizeChoice.allCases) { Text($0.title).tag($0) }
                        }.pickerStyle(.segmented)
                        Button("Reset appearance") { theme.reset() }.buttonStyle(.borderless)
                    }

                    FLCard {
                        Text("Shortcuts").flHeading()
                        Text("Open the Shortcuts app and add “Start focus lock” to your Home Screen or Action Button to start a timer without opening FocusLock. It uses the apps chosen on the Apps tab.")
                            .flBody()
                    }

                    FLCard {
                        Text("What iOS allows").flHeading()
                        Text("Locks are enforced by iOS itself, so they keep working if FocusLock is closed or the phone restarts. iOS does let you revoke Screen Time access in Settings or delete the app, which would remove the lock — no app can prevent that.")
                            .flBody()
                    }
                }
                .padding()
            }
            .background(Color.flBackground.ignoresSafeArea())
            .navigationTitle("Setup")
            .onAppear {
                manager.refresh()
                Notifier.checkPermission { notificationsOK = $0 }
            }
        }
    }

    private func checkRow(_ title: String, _ done: Bool) -> some View {
        HStack {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .foregroundColor(done ? theme.accent : Color.flMuted)
            Text(title).font(.subheadline).foregroundColor(Color.flText)
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}
