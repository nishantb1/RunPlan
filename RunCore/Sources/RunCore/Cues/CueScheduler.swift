import Foundation

/// Turns a stream of engine snapshots into cue events. Holds only what has already been
/// cued, so it gives the same answers however irregularly it is polled.
public struct CueScheduler: Sendable {
    private var lastStepIndex: Int?
    private var beepsPlayed: Set<Int> = []
    private var finishedSent = false

    public init() {}

    public mutating func events(for snapshot: WorkoutEngine.Snapshot) -> [CueEvent] {
        if snapshot.state == .finished {
            guard !finishedSent else { return [] }
            finishedSent = true
            return [.finished]
        }

        if snapshot.stepIndex != lastStepIndex {
            lastStepIndex = snapshot.stepIndex
            beepsPlayed = []
            return [.announce(snapshot.step)]
        }

        guard snapshot.state == .running, let remaining = snapshot.remainingInStep else { return [] }

        var events: [CueEvent] = []
        for mark in [3, 2, 1] where remaining <= Double(mark) && remaining > Double(mark - 1) && !beepsPlayed.contains(mark) {
            beepsPlayed.insert(mark)
            events.append(.countdownBeep)
        }
        return events
    }
}
