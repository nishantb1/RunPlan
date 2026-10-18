import Foundation

/// The runner's settings, stored as one small file.
public struct SettingsStore: Sendable {
    private static let file = "settings.json"
    private let store: JSONStore

    public init(store: JSONStore) {
        self.store = store
    }

    /// The saved settings, or the defaults when none are saved.
    public func load() -> AppSettings {
        store.load(AppSettings.self, from: Self.file) ?? AppSettings()
    }

    public func save(_ settings: AppSettings) throws {
        try store.save(settings, as: Self.file)
    }

    public func delete() {
        store.delete(Self.file)
    }
}
