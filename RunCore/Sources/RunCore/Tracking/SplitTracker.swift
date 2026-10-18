import Foundation

/// Mile splits from cumulative distance and active (unpaused) time. A mile crossed between two
/// updates is timed by straight-line interpolation.
public struct SplitTracker: Codable, Equatable, Sendable {
    /// A partial final split shorter than this (about 0.01 mi) is dropped.
    static let minimumFinalMeters = 16.0

    public private(set) var completed: [Split] = []
    private var lastMeters: Double = 0
    private var lastElapsed: TimeInterval = 0
    private var lastSplitElapsed: TimeInterval = 0

    public init() {}

    /// Returns the splits completed by this update, usually none.
    public mutating func update(totalMeters: Double, elapsed: TimeInterval) -> [Split] {
        var new: [Split] = []
        while totalMeters >= Double(completed.count + 1) * Pace.metersPerMile {
            let boundary = Double(completed.count + 1) * Pace.metersPerMile
            let fraction = totalMeters > lastMeters ? (boundary - lastMeters) / (totalMeters - lastMeters) : 1
            let crossing = lastElapsed + fraction * (elapsed - lastElapsed)
            let split = Split(
                index: completed.count + 1,
                distanceMeters: Pace.metersPerMile,
                durationSeconds: Int((crossing - lastSplitElapsed).rounded())
            )
            completed.append(split)
            new.append(split)
            lastSplitElapsed = crossing
        }
        lastMeters = totalMeters
        lastElapsed = elapsed
        return new
    }

    /// Completed splits plus the partial last one, when it covers at least 16 m. Call `update`
    /// with the same distance first.
    public func allSplits(totalMeters: Double, elapsed: TimeInterval) -> [Split] {
        let remaining = totalMeters - Double(completed.count) * Pace.metersPerMile
        guard remaining >= Self.minimumFinalMeters else { return completed }
        let partial = Split(
            index: completed.count + 1,
            distanceMeters: remaining,
            durationSeconds: Int((elapsed - lastSplitElapsed).rounded())
        )
        return completed + [partial]
    }
}
