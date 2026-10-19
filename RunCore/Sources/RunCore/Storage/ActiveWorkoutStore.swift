import Foundation

/// The crash checkpoint for a workout in progress. The route grows by about a point a second,
/// so it has its own file, written less often than the small checkpoint of clocks and totals.
/// A restored run may miss the last few seconds of its route, but never any distance.
public struct ActiveWorkoutStore: Sendable {
    static let file = "active.json"
    static let routeFile = "active-route.json"
    private let store: JSONStore

    public init(store: JSONStore) {
        self.store = store
    }

    /// Writes the checkpoint without its route, and the route to its own file as well when
    /// `includingRoute` is true.
    public func save(_ active: ActiveWorkout, includingRoute: Bool) throws {
        var small = active
        if var outdoor = small.outdoor {
            if includingRoute {
                try store.save(SavedRoute(startedAt: active.startedAt, points: outdoor.route), as: Self.routeFile)
            }
            outdoor.replaceRoute([])
            small.outdoor = outdoor
        }
        try store.save(small, as: Self.file)
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
