import Foundation

/// A suggested change to a plan's run paces, from how recent runs actually went.
public struct PaceSuggestion: Equatable, Sendable {
    public enum Reason: Equatable, Sendable {
        case ranFaster
        case ranSlower
        case feltEasy
        case feltHard
    }

    /// Seconds per mile to add to the run targets; negative is faster.
    public let change: Int
    /// The plan's easy pace before the change.
    public let currentEasy: Int
    public let reason: Reason

    public var suggestedEasy: Int { currentEasy + change }
}

/// Suggests faster or slower run paces once recent runs consistently miss their targets.
/// Only completed planned runs recorded after `Plan.paceCheckedAt` count.
///
/// - Measured: the latest 3 runs with a measurable run pace are all more than 15 s/mi off
///   target the same way. The change is their median offset, rounded to 5 s/mi and capped at 30.
/// - Felt: failing that, the latest 2 runs both felt too easy (15 s/mi faster) or both too
///   hard (15 s/mi slower).
public enum PaceInsight {
    static let measuredRuns = 3
    static let feltRuns = 2
    static let tolerance = PaceCueMonitor.toleranceSecondsPerMile
    static let maxChange = 30
    static let feltChange = 15
    static let rounding = 5
    /// A treadmill run counts only if it lasted at least its planned time less this.
    static let treadmillShortfallSeconds = 30

    public static func suggestion(for plan: Plan, records: [RunRecord]) -> PaceSuggestion? {
        let runs = records
            .filter { record in plan.paceCheckedAt.map { record.startedAt > $0 } ?? true }
            .sorted { $0.startedAt > $1.startedAt }
            .compactMap { record -> (record: RunRecord, workout: Workout)? in
                guard let id = record.workoutID, let workout = plan.workout(id: id),
                      workout.recordID == record.id, target(of: workout) != nil else { return nil }
                return (record, workout)
            }
        let easy = PaceCalculator.paces(goal: plan.profile.goal, fitness: plan.profile.fitness).easy + plan.paceOffset

        let offsets = Array(runs.compactMap { offset(of: $0.record, against: $0.workout) }.prefix(measuredRuns))
        if offsets.count == measuredRuns,
           offsets.allSatisfy({ $0 < -tolerance }) || offsets.allSatisfy({ $0 > tolerance }) {
            let median = offsets.sorted()[measuredRuns / 2]
            let rounded = Int((Double(median) / Double(rounding)).rounded()) * rounding
            let change = min(max(rounded, -maxChange), maxChange)
            return PaceSuggestion(change: change, currentEasy: easy, reason: change < 0 ? .ranFaster : .ranSlower)
        }

        let feelings = runs.prefix(feltRuns).map(\.record.feeling)
        guard feelings.count == feltRuns else { return nil }
        if feelings.allSatisfy({ $0 == .tooEasy }) {
            return PaceSuggestion(change: -feltChange, currentEasy: easy, reason: .feltEasy)
        }
        if feelings.allSatisfy({ $0 == .tooHard }) {
            return PaceSuggestion(change: feltChange, currentEasy: easy, reason: .feltHard)
        }
        return nil
    }

    /// The run steps' combined target pace: their planned time over their planned miles. Nil
    /// when the workout has no run step with a target.
    static func target(of workout: Workout) -> Int? {
        var seconds = 0.0
        var miles = 0.0
        for step in StepExpander.expand(workout.steps) where step.kind == .run {
            guard let pace = step.targetPaceSecondsPerMile, pace > 0 else { continue }
            if let duration = step.durationSeconds {
                seconds += Double(duration)
                miles += Double(duration) / Double(pace)
            } else if let meters = step.distanceMeters {
                let stepMiles = Pace.miles(fromMeters: meters)
                seconds += stepMiles * Double(pace)
                miles += stepMiles
            }
        }
        guard miles > 0 else { return nil }
        return Int((seconds / miles).rounded())
    }

    /// Actual run pace minus target in seconds per mile, or nil when the run cannot be measured.
    /// Outdoors it comes from the tracked run steps; on a treadmill from the typed distance,
    /// taking off the other steps' planned distance at their targets.
    static func offset(of record: RunRecord, against workout: Workout) -> Int? {
        guard let target = target(of: workout) else { return nil }
        let runSeconds: Double
        let runMeters: Double
        switch record.mode {
        case .outdoor:
            guard let seconds = record.runSeconds, seconds >= 60, let meters = record.runMeters, meters > 0 else { return nil }
            runSeconds = Double(seconds)
            runMeters = meters
        case .treadmill:
            let steps = StepExpander.expand(workout.steps)
            let runs = steps.filter { $0.kind == .run }
            let others = steps.filter { $0.kind != .run }
            guard record.distanceMeters > 0,
                  runs.allSatisfy({ $0.durationSeconds != nil }),
                  others.allSatisfy({ $0.durationSeconds != nil && $0.targetPaceSecondsPerMile != nil }) else { return nil }
            let planned = steps.compactMap(\.durationSeconds).reduce(0, +)
            guard record.durationSeconds >= planned - treadmillShortfallSeconds else { return nil }
            let otherMeters = others.reduce(0.0) { total, step in
                total + Pace.meters(fromMiles: Double(step.durationSeconds ?? 0) / Double(step.targetPaceSecondsPerMile ?? 1))
            }
            runSeconds = Double(runs.compactMap(\.durationSeconds).reduce(0, +))
            runMeters = record.distanceMeters - otherMeters
            guard runSeconds > 0, runMeters > 0 else { return nil }
        }
        let actual = runSeconds / Pace.miles(fromMeters: runMeters)
        return Int(actual.rounded()) - target
    }
}
