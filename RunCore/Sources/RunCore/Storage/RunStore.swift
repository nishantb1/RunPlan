import Foundation

/// Run history: one file per run, so a long history never rewrites one large file. Each run's
/// route has its own file too, so listing runs never loads routes.
public struct RunStore: Sendable {
    private static let folder = "records"
    private static let routeFolder = "routes"
    private let store: JSONStore

    public init(store: JSONStore) {
        self.store = store
    }

    /// Saves a finished run with its route. The route is written first, so the record is the
    /// commit point: an interrupted save leaves at most an unlisted route file, never a listed
    /// run that has lost its route. Records from `all()` carry no route, so do not save one
    /// back as it is.
    public func save(_ record: RunRecord) throws {
        if !record.route.isEmpty {
            try store.save(record.route, as: routeName(record.id))
        }
        var listed = record
        listed.route = []
        try store.save(listed, as: recordName(record.id))
    }

    /// Every readable record, newest first, without routes (see `route(for:)`).
    public func all() -> [RunRecord] {
        store.names(in: Self.folder)
            .filter { $0.hasSuffix(".json") }
            .compactMap { name -> RunRecord? in
                // Older records carry their route inside; drop it straight away.
                guard var record = store.load(RunRecord.self, from: "\(Self.folder)/\(name)") else { return nil }
                record.route = []
                return record
            }
            .sorted { $0.startedAt > $1.startedAt }
    }

    /// The run's route. Records saved before routes had their own files keep it inside.
    public func route(for record: RunRecord) -> [RoutePoint] {
        store.load([RoutePoint].self, from: routeName(record.id))
            ?? store.load(RunRecord.self, from: recordName(record.id))?.route
            ?? []
    }

    /// Deletes every run and route.
    public func deleteAll() {
        store.delete(Self.folder)
        store.delete(Self.routeFolder)
    }

    private func recordName(_ id: UUID) -> String {
        "\(Self.folder)/\(id.uuidString).json"
    }

    private func routeName(_ id: UUID) -> String {
        "\(Self.routeFolder)/\(id.uuidString).json"
    }
}
