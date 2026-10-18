import Foundation

/// Everything measured on an outdoor run: GPS distance and route, smoothed pace, mile splits,
/// and when a distance step is complete or a pace cue is due. It holds only values, so it is
/// unit tested and saved in the crash checkpoint alongside the engine.
public struct OutdoorTracker: Codable, Equatable, Sendable {
    /// With no used fix for this long, the live screen shows a signal warning.
    public static let signalTimeoutSeconds: TimeInterval = 10

    private var distance = DistanceAccumulator()
    private var smoother = PaceSmoother()
    private var splits = SplitTracker()
    private var paceMonitor = PaceCueMonitor()
    private var stepIndex: Int?
    private var stepStartMeters: Double = 0
    private var stepDistanceSent = false
    private var splitCheckedMeters: Double = 0
    public private(set) var lastFixAt: Date?

    public init() {}

    public var totalMeters: Double { distance.totalMeters }
    public var route: [RoutePoint] { distance.route }

    /// Seconds per mile over the last 15 seconds, or nil while there is too little data. It is
    /// not cleared when fixes stop, so check `hasSignal(now:)` before showing it.
    public var currentPace: Int? { smoother.secondsPerMile }

    public func hasSignal(now: Date) -> Bool {
        guard let lastFixAt else { return false }
        return now.timeIntervalSince(lastFixAt) <= Self.signalTimeoutSeconds
    }

    /// Feeds one GPS fix. Inaccurate or stale fixes are ignored. While paused (`counting` false)
    /// a fix moves the reference point but adds no distance, and the pace window restarts.
    public mutating func record(_ sample: LocationSample, now: Date, counting: Bool) {
        guard SampleFilter.accepts(sample, now: now) else { return }
        lastFixAt = sample.timestamp
        distance.add(sample, counting: counting)
        if counting {
            smoother.add(time: sample.timestamp, totalMeters: distance.totalMeters)
        } else {
            smoother.reset()
        }
    }

    /// Splits to announce, pace cues to speak, and whether the current distance step is done
    /// (reported once per step).
    public mutating func events(for snapshot: WorkoutEngine.Snapshot, now: Date) -> [OutdoorEvent] {
        if snapshot.stepIndex != stepIndex {
            stepIndex = snapshot.stepIndex
            stepStartMeters = distance.totalMeters
            stepDistanceSent = false
            paceMonitor.reset()
        }

        var events: [OutdoorEvent] = []
        // Only when distance has changed, so a mile crossed between two fixes is interpolated
        // over the fix interval rather than over the last 0.25 s screen refresh.
        if distance.totalMeters != splitCheckedMeters {
            splitCheckedMeters = distance.totalMeters
            events += splits
                .update(totalMeters: distance.totalMeters, elapsed: snapshot.totalElapsed)
                .map(OutdoorEvent.split)
        }

        guard snapshot.state == .running else {
            paceMonitor.reset()
            return events
        }

        if let target = snapshot.step.distanceMeters, !stepDistanceSent,
           distance.totalMeters - stepStartMeters >= target {
            stepDistanceSent = true
            events.append(.stepDistanceReached)
        }
        let pace = hasSignal(now: now) ? currentPace : nil
        if let cue = paceMonitor.update(pace: pace, target: snapshot.step.targetPaceSecondsPerMile, now: now) {
            events.append(.paceCue(cue))
        }
        return events
    }

    /// Distance left in the current step, or nil when the step is not measured by distance.
    public func stepMetersRemaining(for snapshot: WorkoutEngine.Snapshot) -> Double? {
        guard let target = snapshot.step.distanceMeters else { return nil }
        guard snapshot.stepIndex == stepIndex else { return target }
        return max(0, target - (distance.totalMeters - stepStartMeters))
    }

    /// Completed mile splits plus the partial last one.
    public func finalSplits(elapsed: TimeInterval) -> [Split] {
        splits.allSplits(totalMeters: distance.totalMeters, elapsed: elapsed)
    }
}
