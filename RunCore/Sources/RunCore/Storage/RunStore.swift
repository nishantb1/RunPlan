import Foundation

/// Run history: one file per run, so a long history never rewrites one large file.
public struct RunStore: Sendable {
    private static let folder = "records"
    private let store: JSONStore

    public init(store: JSONStore) {
        self.store = store
    }

    public func save(_ record: RunRecord) throws {
        try store.save(record, as: "\(Self.folder)/\(record.id.uuidString).json")
    }

    /// Every readable record, newest first.
    public func all() -> [RunRecord] {
        store.names(in: Self.folder)
            .filter { $0.hasSuffix(".json") }
            .compactMap { store.load(RunRecord.self, from: "\(Self.folder)/\($0)") }
            .sorted { $0.startedAt > $1.startedAt }
    }
}
