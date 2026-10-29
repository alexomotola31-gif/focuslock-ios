import SwiftUI

@main
struct FocusLockApp: App {
    @StateObject private var manager = LockManager.shared
    @StateObject private var theme = ThemeStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(manager)
                .environmentObject(theme)
                .preferredColorScheme(theme.mode.scheme)
                .tint(theme.accent)
                .dynamicTypeSize(theme.textSize.size)
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active { manager.refresh() }
        }
    }
}
