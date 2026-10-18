import Foundation

/// Fires a pace cue once the smoothed pace has been more than 15 s/mi off the step's target
/// for 30 s, and again every 30 s while it stays off in the same direction.
public struct PaceCueMonitor: Codable, Equatable, Sendable {
    public static let toleranceSecondsPerMile = 15
    public static let holdSeconds: TimeInterval = 30

    private var offSince: Date?
    private var offCue: PaceCue?

    public init() {}

    public mutating func update(pace: Int?, target: Int?, now: Date) -> PaceCue? {
        guard let pace, let target, abs(pace - target) > Self.toleranceSecondsPerMile else {
            reset()
            return nil
        }
        let cue: PaceCue = pace > target ? .speedUp : .slowDown
        guard let since = offSince, offCue == cue else {
            offSince = now
            offCue = cue
            return nil
        }
        guard now.timeIntervalSince(since) >= Self.holdSeconds else { return nil }
        offSince = now
        return cue
    }

    /// Call on a step change or pause.
    public mutating func reset() {
        offSince = nil
        offCue = nil
    }
}
