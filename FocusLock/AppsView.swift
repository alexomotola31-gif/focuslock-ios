import SwiftUI
import FamilyControls

/// iOS doesn't let apps list installed apps, so selection happens in Apple's
/// own picker (which shows real icons and names, and whole categories such as
/// Social, Games, Finance). The chosen apps show here with their icons.
struct AppsView: View {
    @EnvironmentObject var manager: LockManager
    @EnvironmentObject var theme: ThemeStore
    @State private var showPicker = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button(manager.defaultSelection.hasItems ? "Edit selection" : "Choose apps & categories") {
                        showPicker = true
                    }
                    .buttonStyle(AccentButtonStyle())
                    .listRowBackground(Color.clear)
                }
                if manager.defaultSelection.hasItems {
                    if !manager.defaultSelection.categoryTokens.isEmpty {
                        Section("Categories (all apps inside are blocked)") {
                            ForEach(Array(manager.defaultSelection.categoryTokens), id: \.self) { token in
                                Label(token).labelStyle(.titleAndIcon)
                            }
                        }
                    }
                    if !manager.defaultSelection.applicationTokens.isEmpty {
                        Section("Apps") {
                            ForEach(Array(manager.defaultSelection.applicationTokens), id: \.self) { token in
                                Label(token).labelStyle(.titleAndIcon)
                            }
                        }
                    }
                } else {
                    Section {
                        Text("Nothing selected. Timer locks use this list; each schedule can use its own.")
                            .flBody()
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.flBackground.ignoresSafeArea())
            .navigationTitle("Apps")
        }
        .familyActivityPicker(isPresented: $showPicker, selection: $manager.defaultSelection)
    }
}
