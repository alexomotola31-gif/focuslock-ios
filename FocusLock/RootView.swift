import SwiftUI

struct RootView: View {
    @EnvironmentObject var manager: LockManager
    @EnvironmentObject var theme: ThemeStore
    @AppStorage("fl.onboarded") private var onboarded = false
    @State private var showSplash = true

    var body: some View {
        ZStack {
            Color.flBackground.ignoresSafeArea()
            if showSplash {
                SplashView()
                    .transition(.opacity)
            } else if !onboarded {
                OnboardingView(onboarded: $onboarded)
            } else {
                MainTabs()
            }
        }
        .task {
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            withAnimation(.easeOut(duration: 0.35)) { showSplash = false }
            manager.refresh()
        }
    }
}

struct SplashView: View {
    @EnvironmentObject var theme: ThemeStore

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.03, green: 0.05, blue: 0.14), Color(red: 0.10, green: 0.08, blue: 0.28)],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()
            VStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 22)
                        .fill(Color(red: 0.07, green: 0.10, blue: 0.22))
                        .frame(width: 84, height: 84)
                    Circle().stroke(Color(red: 1.0, green: 0.74, blue: 0.2), lineWidth: 4)
                        .frame(width: 58, height: 58)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color(red: 0.35, green: 0.62, blue: 1.0))
                }
                HStack(spacing: 0) {
                    Text("Focus").foregroundColor(.white)
                    Text("Lock").foregroundColor(Color(red: 0.62, green: 0.55, blue: 1.0))
                }
                .font(.system(size: 38, weight: .bold, design: .serif))
                Text("Lock in. Stay focused.")
                    .font(.subheadline)
                    .foregroundColor(Color(red: 0.75, green: 0.72, blue: 0.95))
            }
        }
    }
}

/// iOS equivalent of the Android accessibility disclosure: explains exactly
/// what the Screen Time permission is used for before asking for it.
struct OnboardingView: View {
    @EnvironmentObject var manager: LockManager
    @EnvironmentObject var theme: ThemeStore
    @Binding var onboarded: Bool
    @State private var message: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Welcome to FocusLock")
                    .font(.system(.largeTitle, design: .serif).bold())
                    .foregroundColor(theme.accent)
                FLCard {
                    Text("What FocusLock does").flHeading()
                    Text("It blocks the apps you choose for a time you choose, and you can't cancel early. Each timer gives you a one-time 6-digit emergency code (max 3 uses per day). Scheduled locks have no code at all.")
                        .flBody()
                }
                FLCard {
                    Text("Screen Time permission").flHeading()
                    Text("FocusLock uses Apple's Screen Time framework to shield apps. It never sees which apps you open, your browsing, or your content. The list of apps you pick stays on this device.")
                        .flBody()
                    if let message = message { Text(message).font(.footnote).foregroundColor(.red) }
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
                }
                Button("Continue") { onboarded = true }
                    .buttonStyle(AccentButtonStyle())
            }
            .padding()
        }
    }
}

struct MainTabs: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }
            AppsView()
                .tabItem { Label("Apps", systemImage: "square.grid.2x2.fill") }
            ScheduleView()
                .tabItem { Label("Schedule", systemImage: "calendar") }
            InsightsView()
                .tabItem { Label("Progress", systemImage: "chart.bar.fill") }
            SetupView()
                .tabItem { Label("Setup", systemImage: "gearshape.fill") }
        }
    }
}
