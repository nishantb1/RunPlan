import Foundation

/// The crash checkpoint for a workout in progress. The route grows by about a point a second,
/// so it has its own file, written less often than the small checkpoint of clocks and totals.
/// A restored run's distance is as current as the last checkpoint; its route may end earlier,
/// by up to the interval the caller saves the route at, and is never ahead of the distance.
public struct ActiveWorkoutStore: Sendable {
    static let file = "active.json"
    static let routeFile = "active-route.json"
    private let store: JSONStore

    public init(store: JSONStore) {
        self.store = store
    }

    /// Writes the checkpoint without its route, then the route to its own file as well when
    /// `includingRoute` is true. The checkpoint goes first, so a failed or interrupted route
    /// write never costs the checkpoint.
    public func save(_ active: ActiveWorkout, includingRoute: Bool) throws {
        guard let outdoor = active.outdoor else {
            try store.save(active, as: Self.file)
            return
        }
        var small = active
        var stripped = outdoor
        stripped.replaceRoute([])
        small.outdoor = stripped
        try store.save(small, as: Self.file)
        if includingRoute {
            try store.save(SavedRoute(startedAt: active.startedAt, points: outdoor.route), as: Self.routeFile)
        }
    }

    /// The unfinished workout with the route last saved for it, or nil when there is none.
    public func load() -> ActiveWorkout? {
        guard var active = store.load(ActiveWorkout.self, from: Self.file) else { return nil }
        // Checkpoints written before the route had its own file still hold it inside.
        if var outdoor = active.outdoor, outdoor.route.isEmpty,
           let saved = store.load(SavedRoute.self, from: Self.routeFile),
           saved.startedAt == active.startedAt {
            outdoor.replaceRoute(saved.points)
            active.outdoor = outdoor
        }
        return active
    }

    public func delete() {
        store.delete(Self.file)
        store.delete(Self.routeFile)
    }

    /// The route on disk, tagged with its workout's start so a file left from another workout
    /// is never attached to this one.
    private struct SavedRoute: Codable {
        var startedAt: Date
        var points: [RoutePoint]
    }
}
