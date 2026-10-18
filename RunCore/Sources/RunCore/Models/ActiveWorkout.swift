import Foundation

/// A workout in progress, written to disk every few seconds so it can be resumed if the
/// app is killed.
public struct ActiveWorkout: Codable, Equatable, Sendable {
    public var workout: Workout
    public var mode: RunMode
    public var startedAt: Date
    public var checkpoint: WorkoutEngine.Checkpoint
    /// Outdoor runs only: distance, route, pace window and splits so far.
    public var outdoor: OutdoorTracker?

    public init(
        workout: Workout,
        mode: RunMode,
        startedAt: Date,
        checkpoint: WorkoutEngine.Checkpoint,
        outdoor: OutdoorTracker? = nil
    ) {
        self.workout = workout
        self.mode = mode
        self.startedAt = startedAt
        self.checkpoint = checkpoint
        self.outdoor = outdoor
    }
}
