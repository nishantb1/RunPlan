import Foundation

/// Decides when an outdoor run should pause because the runner has stopped, and resume when
/// they set off again, from straight-line speed over the last 6 seconds of fixes. Straight line
/// is used because jitter adds to a path length; the cost is that a very sharp turnaround can
/// pause briefly, which corrects itself a few seconds later.
public struct AutoPauseDetector: Codable, Equatable, Sendable {
    public enum Action: String, Codable, Sendable {
        case pause
        case resume
    }

    static let windowSeconds: TimeInterval = 6
    static let minimumSpanSeconds: TimeInterval = 4
    /// Slower than this while running means the runner has stopped.
    static let stoppedMetersPerSecond = 0.5
    /// Faster than this after an automatic pause means they have set off again. The gap between
    /// the two thresholds stops GPS jitter flipping between paused and running.
    static let movingMetersPerSecond = 1.2
    /// The most a resume must move away from where the runner stopped: their two readings'
    /// accuracy, capped here, so GPS wander while standing still never resumes the run.
    static let maxNoiseFloorMeters = 15.0

    private var fixes: [LocationSample] = []
    /// Where the runner stopped. Measuring the resume from here, not across the 6 s window,
    /// lets a walk resume too: at walking pace the window alone never clears the accuracy.
    private var stoppedAt: LocationSample?
    public private(set) var isAutoPaused = false

    public init() {}

    /// Feed every fix that passed `SampleFilter`. `isRunning` is whether the workout is running
    /// (not paused). Returns the change to make, if any.
    public mutating func update(_ sample: LocationSample, isRunning: Bool) -> Action? {
        fixes.append(sample)
        fixes.removeAll { sample.timestamp.timeIntervalSince($0.timestamp) > Self.windowSeconds }
        guard let first = fixes.first else { return nil }
        let span = sample.timestamp.timeIntervalSince(first.timestamp)
        guard span >= Self.minimumSpanSeconds else { return nil }
        let speed = Geo.distance(first, sample) / span

        if isRunning, !isAutoPaused, speed < Self.stoppedMetersPerSecond {
            isAutoPaused = true
            stoppedAt = sample
            return .pause
        }
        if isAutoPaused, speed > Self.movingMetersPerSecond, let stoppedAt {
            let noiseFloor = min(stoppedAt.horizontalAccuracy + sample.horizontalAccuracy, Self.maxNoiseFloorMeters)
            guard Geo.distance(stoppedAt, sample) > noiseFloor else { return nil }
            isAutoPaused = false
            self.stoppedAt = nil
            return .resume
        }
        return nil
    }

    /// Call when the runner pauses or resumes by hand. A manual pause is then never resumed
    /// automatically, and after a manual resume the detector waits for fresh fixes rather than
    /// judging the runner by the seconds they spent standing still.
    public mutating func manualOverride() {
        isAutoPaused = false
        stoppedAt = nil
        fixes.removeAll()
    }
}
