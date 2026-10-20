import Foundation

/// What to offer when a plan is over: train for the same distance from the finale's time, or
/// step up from 5K to 10K.
public enum FollowUp {
    public static let sameDistanceWeeks = 8
    public static let longerDistanceWeeks = 10
    /// Faster than 4:00 /mi is not a plausible finale estimate, e.g. after ending early.
    static let fastestPlausiblePace = 240

    /// The time for the goal distance in the plan's finale: its recorded time less its timed
    /// non-run steps. Nil when the last workout is not a completed time trial or the estimate
    /// is implausible.
    public static func finaleSeconds(of plan: Plan, records: [RunRecord]) -> Int? {
        guard let finale = plan.workouts.last, finale.kind == .timeTrial,
              let recordID = finale.recordID,
              let record = records.first(where: { $0.id == recordID }) else { return nil }
        let walking = StepExpander.expand(finale.steps)
            .filter { $0.kind != .run }
            .compactMap(\.durationSeconds)
            .reduce(0, +)
        let seconds = record.durationSeconds - walking
        guard PaceCalculator.pace(seconds: seconds, over: plan.profile.goal.distance) >= fastestPlausiblePace else { return nil }
        return seconds
    }

    /// Answers for the next plan: `distance` with no goal time, starting `start` on the same run
    /// days. Fitness is the finale time when there is one, and running 20 minutes otherwise.
    public static func profile(after plan: Plan, distance: RaceDistance, finaleSeconds: Int?, start: Date) -> Profile {
        let fitness: Fitness = finaleSeconds.map { .recentRace(distance: plan.profile.goal.distance, seconds: $0) }
            ?? .runsTwentyMinutes
        return Profile(
            goal: Goal(distance: distance),
            fitness: fitness,
            runDays: plan.profile.runDays,
            planWeeks: distance == plan.profile.goal.distance ? sameDistanceWeeks : longerDistanceWeeks,
            startDate: start
        )
    }
}
