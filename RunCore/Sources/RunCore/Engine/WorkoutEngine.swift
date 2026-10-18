import Foundation

/// Drives a workout purely from wall-clock time. The start of the current "phase" is stored;
/// the current step and remaining time are recomputed from the supplied `now` on every call
/// to `snapshot(now:)`. A UI timer only decides when to ask for a fresh snapshot.
///
/// A new phase starts at workout start and after every manual advance or skip, because an
/// open-ended step's real duration is not known ahead of time.
public final class WorkoutEngine {

    public enum State: String, Codable, Sendable {
        case notStarted
        case running
        case paused
        case finished
    }

    public struct Snapshot: Equatable, Sendable {
        public let state: State
        public let stepIndex: Int
        public let stepCount: Int
        public let step: FlatStep
        public let elapsedInStep: TimeInterval
        public let remainingInStep: TimeInterval?
        public let totalElapsed: TimeInterval
        /// Time actually spent, excluding pauses. Unlike `totalElapsed`, which tracks progress
        /// through the plan, it never goes back on skip back, so splits and pace use it.
        public let activeElapsed: TimeInterval
        /// Sum of timed step durations. Distance and open steps do not contribute.
        public let totalPlanned: TimeInterval
        public let nextStep: FlatStep?
    }

    /// Everything needed to rebuild the engine after the app is killed.
    public struct Checkpoint: Codable, Equatable, Sendable {
        public var state: State = .notStarted
        public var phaseStartIndex: Int = 0
        public var phaseStartTime: Date?
        public var pauseStartedAt: Date?
        public var accumulatedPause: TimeInterval = 0
        /// Elapsed time from steps before the current phase.
        public var bankedElapsed: TimeInterval = 0
        /// Time actually spent before the current phase, kept through skip back. nil in
        /// checkpoints saved before it existed.
        public var activeBanked: TimeInterval?
        public var savedAt: Date?

        public init() {}
    }

    public let steps: [FlatStep]
    private var core: Checkpoint

    public var state: State { core.state }

    /// - Parameter restoring: a saved checkpoint. If it was running when saved, the engine
    ///   comes back paused at the save time, so time the app spent dead is not counted.
    public init(steps: [FlatStep], restoring checkpoint: Checkpoint? = nil) {
        self.steps = steps
        var restored = checkpoint ?? Checkpoint()
        if restored.state == .running, let savedAt = restored.savedAt {
            restored.pauseStartedAt = savedAt
            restored.state = .paused
        }
        if restored.phaseStartIndex >= steps.count {
            restored = Checkpoint()
        }
        self.core = restored
    }

    public convenience init(planSteps: [Step]) {
        self.init(steps: StepExpander.expand(planSteps))
    }

    public var totalPlanned: TimeInterval {
        steps.compactMap { $0.durationSeconds.map(TimeInterval.init) }.reduce(0, +)
    }

    public func checkpoint(now: Date = Date()) -> Checkpoint {
        var copy = core
        copy.savedAt = now
        return copy
    }

    public func start(now: Date = Date()) {
        guard core.state == .notStarted, !steps.isEmpty else { return }
        core = Checkpoint()
        core.activeBanked = 0
        core.phaseStartTime = now
        core.state = .running
    }

    public func pause(now: Date = Date()) {
        guard core.state == .running else { return }
        core.pauseStartedAt = now
        core.state = .paused
    }

    public func resume(now: Date = Date()) {
        guard core.state == .paused, let pausedAt = core.pauseStartedAt else { return }
        core.accumulatedPause += now.timeIntervalSince(pausedAt)
        core.pauseStartedAt = nil
        core.state = .running
    }

    public func end() {
        core.state = .finished
    }

    /// Ends the current step immediately. This is how a distance step is completed, and it
    /// doubles as skip forward for a timed step. Finishes the workout on the last step.
    public func advanceToNextStep(now: Date = Date()) {
        guard core.state == .running || core.state == .paused else { return }
        guard let resolution = currentResolution(now: now) else { return }

        let absoluteIndex = core.phaseStartIndex + resolution.index
        let elapsedInPhase = phaseElapsed(now: now)
        core.activeBanked = bankedActiveTime + elapsedInPhase
        core.bankedElapsed += elapsedInPhase

        if absoluteIndex >= steps.count - 1 {
            // Keep the banked total readable after finishing.
            core.phaseStartTime = nil
            core.state = .finished
            return
        }

        startPhase(at: absoluteIndex + 1, now: now)
    }

    public func skipForward(now: Date = Date()) {
        advanceToNextStep(now: now)
    }

    /// Goes back to the start of the previous step, or restarts the first step.
    public func skipBack(now: Date = Date()) {
        guard core.state == .running || core.state == .paused else { return }
        guard let resolution = currentResolution(now: now) else { return }

        let absoluteIndex = core.phaseStartIndex + resolution.index
        let targetIndex = max(0, absoluteIndex - 1)

        core.activeBanked = bankedActiveTime + phaseElapsed(now: now)
        core.bankedElapsed = plannedDuration(before: targetIndex)
        startPhase(at: targetIndex, now: now)
    }

    public func snapshot(now: Date = Date()) -> Snapshot? {
        guard core.state != .notStarted else { return nil }

        guard core.phaseStartTime != nil, let resolution = currentResolution(now: now) else {
            // Finished by a manual advance past the last step.
            guard let last = steps.last else { return nil }
            return Snapshot(
                state: core.state,
                stepIndex: steps.count - 1,
                stepCount: steps.count,
                step: last,
                elapsedInStep: 0,
                remainingInStep: 0,
                totalElapsed: core.bankedElapsed,
                activeElapsed: bankedActiveTime,
                totalPlanned: totalPlanned,
                nextStep: nil
            )
        }

        let absoluteIndex = core.phaseStartIndex + resolution.index
        if resolution.isPastEnd, core.state == .running {
            core.state = .finished
        }

        return Snapshot(
            state: core.state,
            stepIndex: absoluteIndex,
            stepCount: steps.count,
            step: steps[absoluteIndex],
            elapsedInStep: resolution.elapsedInStep,
            remainingInStep: resolution.remainingInStep,
            totalElapsed: core.bankedElapsed + phaseElapsed(now: now),
            activeElapsed: bankedActiveTime + phaseElapsed(now: now),
            totalPlanned: totalPlanned,
            nextStep: absoluteIndex + 1 < steps.count ? steps[absoluteIndex + 1] : nil
        )
    }

    // MARK: - Private helpers

    /// Active time banked before the current phase. Older checkpoints fall back to the plan's
    /// banked time, which matches it unless the runner skipped back.
    private var bankedActiveTime: TimeInterval {
        core.activeBanked ?? core.bankedElapsed
    }

    private func startPhase(at index: Int, now: Date) {
        let wasPaused = core.state == .paused
        core.phaseStartIndex = index
        core.phaseStartTime = now
        core.accumulatedPause = 0
        core.pauseStartedAt = wasPaused ? now : nil
    }

    private func phaseElapsed(now: Date) -> TimeInterval {
        guard let phaseStartTime = core.phaseStartTime else { return 0 }
        let pausedNow = core.pauseStartedAt.map { now.timeIntervalSince($0) } ?? 0
        return max(0, now.timeIntervalSince(phaseStartTime) - core.accumulatedPause - pausedNow)
    }

    private func currentResolution(now: Date) -> StepResolution? {
        guard core.phaseStartIndex < steps.count else { return nil }
        let phaseSteps = Array(steps[core.phaseStartIndex...])
        return StepResolver.resolve(steps: phaseSteps, elapsed: phaseElapsed(now: now))
    }

    private func plannedDuration(before index: Int) -> TimeInterval {
        steps.prefix(index).reduce(0) { $0 + ($1.durationSeconds.map(TimeInterval.init) ?? 0) }
    }
}
