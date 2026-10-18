import Foundation

/// Builds each kind of planned workout. `level` is the week's easy-run length in minutes. A
/// tempo session and an intervals session at the same level last exactly as long, so
/// alternating them leaves weekly volume unchanged.
struct WorkoutBuilder {
    static let walkWarmupSeconds = 300
    static let walkCooldownSeconds = 300
    static let trialWarmupSeconds = 600
    static let trialCooldownSeconds = 300
    static let recoverySeconds = 90
    static let minimumWarmupSeconds = 180
    static let intervalRepeats = 2...8

    let paces: TrainingPaces
    let goal: Goal

    /// Interval rep length: 2 minutes for a 5K goal, 3 for 10K.
    var repSeconds: Int {
        switch goal.distance {
        case .fiveK: return 120
        case .tenK: return 180
        }
    }

    func easy(minutes: Int, on date: Date) -> Workout {
        Workout(date: date, kind: .easy, title: "Easy run · \(minutes) min", steps: [
            Step(kind: .run, measure: .time(seconds: minutes * 60), targetPaceSecondsPerMile: paces.easy),
        ])
    }

    func longRun(minutes: Int, on date: Date) -> Workout {
        Workout(date: date, kind: .longRun, title: "Long run · \(minutes) min", steps: [
            Step(kind: .run, measure: .time(seconds: minutes * 60), targetPaceSecondsPerMile: paces.easy),
        ])
    }

    func tempo(level: Int, on date: Date) -> Workout {
        let parts = Self.tempoParts(level: level)
        return Workout(date: date, kind: .tempo, title: "Tempo · \(parts.block / 60) min", steps: [
            Step(kind: .warmup, measure: .time(seconds: parts.warmup), targetPaceSecondsPerMile: paces.easy),
            Step(kind: .run, measure: .time(seconds: parts.block), targetPaceSecondsPerMile: paces.tempo),
            Step(kind: .cooldown, measure: .time(seconds: parts.cooldown), targetPaceSecondsPerMile: paces.easy),
        ])
    }

    /// Reps and recoveries filling the tempo block; the warm-up absorbs what is left over.
    func intervals(level: Int, on date: Date) -> Workout {
        let parts = Self.tempoParts(level: level)
        let cycle = repSeconds + Self.recoverySeconds
        let fitted = Scaling.round(parts.block, times: 1, over: cycle)
        let repeats = min(max(fitted, Self.intervalRepeats.lowerBound), Self.intervalRepeats.upperBound)
        let warmup = max(Self.minimumWarmupSeconds, parts.warmup + parts.block - repeats * cycle)
        return Workout(date: date, kind: .intervals, title: "Intervals · \(repeats) × \(Pace.clock(repSeconds))", steps: [
            Step(kind: .warmup, measure: .time(seconds: warmup), targetPaceSecondsPerMile: paces.easy),
            Step(kind: .run, measure: .time(seconds: repSeconds), targetPaceSecondsPerMile: paces.interval, repeatGroup: 1, repeatCount: repeats),
            Step(kind: .recovery, measure: .time(seconds: Self.recoverySeconds), targetPaceSecondsPerMile: paces.easy, repeatGroup: 1, repeatCount: repeats),
            Step(kind: .cooldown, measure: .time(seconds: parts.cooldown), targetPaceSecondsPerMile: paces.easy),
        ])
    }

    /// Walking warm-up, `level.repeats` × (run, walk), walking cool-down. The long session gets
    /// one extra rep. No pace targets: a new runner goes by feel.
    func walkRun(_ level: WalkRunLevel, extraRep: Bool, on date: Date) -> Workout {
        let repeats = level.repeats + (extraRep ? 1 : 0)
        return Workout(date: date, kind: .walkRun, title: "Run-walk · \(repeats) × \(Pace.clock(level.runSeconds))", steps: [
            Step(kind: .warmup, measure: .time(seconds: Self.walkWarmupSeconds)),
            Step(kind: .run, measure: .time(seconds: level.runSeconds), repeatGroup: 1, repeatCount: repeats),
            Step(kind: .walk, measure: .time(seconds: level.walkSeconds), repeatGroup: 1, repeatCount: repeats),
            Step(kind: .cooldown, measure: .time(seconds: Self.walkCooldownSeconds)),
        ])
    }

    /// The goal distance as one open-ended run. After a walk-run phase the warm-up and
    /// cool-down are walks and there are no targets.
    func timeTrial(afterWalkRun: Bool, on date: Date) -> Workout {
        let distance = StepMeasure.distance(meters: goal.distance.meters)
        let steps: [Step]
        if afterWalkRun {
            steps = [
                Step(kind: .warmup, measure: .time(seconds: Self.walkWarmupSeconds)),
                Step(kind: .run, measure: distance),
                Step(kind: .cooldown, measure: .time(seconds: Self.walkCooldownSeconds)),
            ]
        } else {
            steps = [
                Step(kind: .warmup, measure: .time(seconds: Self.trialWarmupSeconds), targetPaceSecondsPerMile: paces.easy),
                Step(kind: .run, measure: distance, targetPaceSecondsPerMile: paces.goal),
                Step(kind: .cooldown, measure: .time(seconds: Self.trialCooldownSeconds), targetPaceSecondsPerMile: paces.easy),
            ]
        }
        return Workout(date: date, kind: .timeTrial, title: "\(goal.distance.displayName) time trial", steps: steps)
    }

    /// Warm-up, tempo block and cool-down in seconds: 30, 50 and 20 percent of `level` minutes.
    static func tempoParts(level: Int) -> (warmup: Int, block: Int, cooldown: Int) {
        (
            warmup: Scaling.round(level, times: 3, over: 10) * 60,
            block: Scaling.round(level, times: 1, over: 2) * 60,
            cooldown: Scaling.round(level, times: 1, over: 5) * 60
        )
    }
}
