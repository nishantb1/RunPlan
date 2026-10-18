import Foundation

/// Training paces and the goal check. Paces are in seconds per mile.
///
/// Times at different distances are related with Riegel's formula, t2 = t1 × (d2 / d1)^1.06.
/// Training paces hang off 5K pace: intervals at 5K pace, tempo 25 s/mi slower, easy 90 s/mi
/// slower.
public enum PaceCalculator {
    static let riegelExponent = 1.06
    static let tempoOffset = 25
    static let easyOffset = 90
    /// Improvement per training week that the goal check treats as plausible.
    static let weeklyImprovement = 0.01

    /// The time at `to` equivalent to `seconds` at `from`.
    public static func equivalentTime(seconds: Int, from: RaceDistance, to: RaceDistance) -> Int {
        Int((Double(seconds) * pow(to.meters / from.meters, riegelExponent)).rounded())
    }

    /// Average pace for covering `distance` in `seconds`.
    public static func pace(seconds: Int, over distance: RaceDistance) -> Int {
        Int((Double(seconds) / Pace.miles(fromMeters: distance.meters)).rounded())
    }

    /// Paces from the goal time, or from a recent race when the goal is to finish. With
    /// neither, the conservative defaults.
    public static func paces(goal: Goal, fitness: Fitness) -> TrainingPaces {
        let fiveKSeconds: Int
        let goalPace: Int
        if let target = goal.targetSeconds {
            fiveKSeconds = equivalentTime(seconds: target, from: goal.distance, to: .fiveK)
            goalPace = pace(seconds: target, over: goal.distance)
        } else if case .recentRace(let distance, let seconds) = fitness {
            fiveKSeconds = equivalentTime(seconds: seconds, from: distance, to: .fiveK)
            goalPace = pace(seconds: equivalentTime(seconds: seconds, from: distance, to: goal.distance), over: goal.distance)
        } else {
            return .defaults
        }
        let fiveKPace = pace(seconds: fiveKSeconds, over: .fiveK)
        return TrainingPaces(
            easy: fiveKPace + easyOffset,
            tempo: fiveKPace + tempoOffset,
            interval: fiveKPace,
            goal: goalPace
        )
    }

    /// Whether the goal time is plausible in `planWeeks` weeks from the runner's current ability.
    public static func assess(_ profile: Profile) -> GoalAssessment {
        guard let target = profile.goal.targetSeconds else { return .reachable }
        let current = currentTime(at: profile.goal.distance, fitness: profile.fitness)
        let needed = 1 - Double(target) / Double(current)
        if needed <= weeklyImprovement * Double(profile.planWeeks) {
            return .reachable
        }
        let weeks = Int((needed / weeklyImprovement).rounded(.up))
        return .ambitious(suggestedWeeks: Profile.planWeeksRange.contains(weeks) ? weeks : nil)
    }

    /// What the runner could run `distance` in today: their race result scaled to that
    /// distance, or a typical time for their fitness level.
    static func currentTime(at distance: RaceDistance, fitness: Fitness) -> Int {
        switch fitness {
        case .recentRace(let raceDistance, let seconds):
            return equivalentTime(seconds: seconds, from: raceDistance, to: distance)
        case .newRunner:
            return equivalentTime(seconds: 2700, from: .fiveK, to: distance)
        case .runsFiveMinutes:
            return equivalentTime(seconds: 2400, from: .fiveK, to: distance)
        case .runsTwentyMinutes:
            return equivalentTime(seconds: 2100, from: .fiveK, to: distance)
        }
    }
}
