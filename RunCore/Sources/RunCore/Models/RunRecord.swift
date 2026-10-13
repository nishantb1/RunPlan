import Foundation

/// A completed run. `workoutID` is nil for a free run with no planned workout.
public struct RunRecord: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var workoutID: UUID?
    public var title: String
    public var mode: RunMode
    public var startedAt: Date
    public var durationSeconds: Int
    public var distanceMeters: Double
    public var perceivedEffort: Int?
    public var notes: String
    public var splits: [Split]
    public var route: [RoutePoint]

    public init(
        id: UUID = UUID(),
        workoutID: UUID? = nil,
        title: String = "Run",
        mode: RunMode,
        startedAt: Date,
        durationSeconds: Int,
        distanceMeters: Double,
        perceivedEffort: Int? = nil,
        notes: String = "",
        splits: [Split] = [],
        route: [RoutePoint] = []
    ) {
        self.id = id
        self.workoutID = workoutID
        self.title = title
        self.mode = mode
        self.startedAt = startedAt
        self.durationSeconds = durationSeconds
        self.distanceMeters = distanceMeters
        self.perceivedEffort = perceivedEffort
        self.notes = notes
        self.splits = splits
        self.route = route
    }
}
