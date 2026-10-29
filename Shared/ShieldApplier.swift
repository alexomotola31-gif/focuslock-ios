import Foundation
import FamilyControls
import ManagedSettings

/// Applies/clears OS-level shields. Each lock owns a named store, and iOS
/// combines all stores, so overlapping locks work and ending one never
/// lifts another.
enum ShieldApplier {
    static func store(_ name: String) -> ManagedSettingsStore {
        ManagedSettingsStore(named: ManagedSettingsStore.Name(name))
    }

    static func apply(name: String, selectionData: Data) {
        guard let selection = try? JSONDecoder().decode(
            FamilyActivitySelection.self, from: selectionData
        ) else { return }
        let target = store(name)
        target.shield.applications = selection.applicationTokens.isEmpty
            ? nil : selection.applicationTokens
        target.shield.webDomains = selection.webDomainTokens.isEmpty
            ? nil : selection.webDomainTokens
        if selection.categoryTokens.isEmpty {
            target.shield.applicationCategories = nil
            target.shield.webDomainCategories = nil
        } else {
            target.shield.applicationCategories = .specific(selection.categoryTokens)
            target.shield.webDomainCategories = .specific(selection.categoryTokens)
        }
    }

    static func clear(name: String) {
        store(name).clearAllSettings()
    }
}
