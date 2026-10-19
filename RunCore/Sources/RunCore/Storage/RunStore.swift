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
    /// run that has lost its route. A record from `all()` carries no route; if its file still
    /// holds one from before routes had their own files, that route is moved across, not lost.
    /// An empty route never clears a route already saved.
    public func save(_ record: RunRecord) throws {
        let route = record.route.isEmpty ? embeddedRoute(record.id) : record.route
        if !route.isEmpty {
            try store.save(route, as: routeName(record.id))
        }
        var listed = record
        listed.route = []
        try store.save(listed, as: recordName(record.id))
    }

    /// Moves routes still kept inside older records into their own files, so listing runs no
    /// longer decodes them. Cheap once every route has moved, so it runs at each launch.
    public func moveEmbeddedRoutes() {
        for name in recordNames() {
            guard let record = store.load(RunRecord.self, from: "\(Self.folder)/\(name)"),
                  !record.route.isEmpty else { continue }
            try? save(record)
        }
    }

    /// Every readable record, newest first, without routes (see `route(for:)`).
    public func all() -> [RunRecord] {
        recordNames()
            .compactMap { name -> RunRecord? in
                // Older records carry their route inside; drop it straight away.
                guard var record = store.load(RunRecord.self, from: "\(Self.folder)/\(name)") else { return nil }
                record.route = []
                return record
            }
            .sorted { $0.startedAt > $1.startedAt }
    }

    /// The run's route. Records saved before routes had their own files keep it inside until
    /// `moveEmbeddedRoutes()` runs.
    public func route(for record: RunRecord) -> [RoutePoint] {
        store.load([RoutePoint].self, from: routeName(record.id)) ?? embeddedRoute(record.id)
    }

    /// Deletes every run and route.
    public func deleteAll() {
        store.delete(Self.folder)
        store.delete(Self.routeFolder)
    }

    private func recordNames() -> [String] {
        store.names(in: Self.folder).filter { $0.hasSuffix(".json") }
    }

    /// The route inside a record's own file, from before routes had their own files.
    private func embeddedRoute(_ id: UUID) -> [RoutePoint] {
        store.load(RunRecord.self, from: recordName(id))?.route ?? []
    }

    private func recordName(_ id: UUID) -> String {
        "\(Self.folder)/\(id.uuidString).json"
    }

    private func routeName(_ id: UUID) -> String {
        "\(Self.routeFolder)/\(id.uuidString).json"
    }
}
