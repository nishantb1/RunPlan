import Foundation

/// Time and distance covered while a run step is running, so a run-walk's running pace can be
/// told apart from its walks. Used for pace suggestions.
struct RunPortion: Codable, Equatable, Sendable {
    private(set) var seconds: TimeInterval = 0
    private(set) var meters: Double = 0
    private var lastElapsed: TimeInterval?
    private var lastMeters: Double?

    /// Call on every update. What changed since the previous call counts when `counting`: the
    /// workout is running a run step.
    mutating func update(elapsed: TimeInterval, totalMeters: Double, counting: Bool) {
        if counting, let lastElapsed, let lastMeters {
            seconds += max(0, elapsed - lastElapsed)
            meters += max(0, totalMeters - lastMeters)
        }
        lastElapsed = elapsed
        lastMeters = totalMeters
    }
}
