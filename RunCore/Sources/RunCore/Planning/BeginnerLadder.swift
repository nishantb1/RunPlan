import Foundation

/// The beginner 5K progression: run-walk steps whose walks shrink as the runs grow, then
/// continuous runs in 5-minute steps up to the top, the minutes a 5K takes at easy pace.
/// See docs/superpowers/specs/2026-10-19-beginner-5k-plan-design.md.
struct BeginnerLadder: Equatable, Sendable {
    enum Rung: Equatable, Sendable {
        case runWalk(WalkRunLevel)
        case continuous(minutes: Int)
    }

    /// Ends at 2 × 10:00 with a 1:00 walk, so the first continuous 20 minutes is a short step.
    static let runWalkRungs: [WalkRunLevel] = [
        WalkRunLevel(runSeconds: 60, walkSeconds: 90, repeats: 8),
        WalkRunLevel(runSeconds: 90, walkSeconds: 90, repeats: 7),
        WalkRunLevel(runSeconds: 150, walkSeconds: 90, repeats: 6),
        WalkRunLevel(runSeconds: 240, walkSeconds: 90, repeats: 4),
        WalkRunLevel(runSeconds: 360, walkSeconds: 60, repeats: 3),
        WalkRunLevel(runSeconds: 600, walkSeconds: 60, repeats: 2),
    ]
    static let firstContinuousMinutes = 20
    static let continuousStepMinutes = 5
    static let topMinutesRange = 30...45
    /// The most a build week moves up the ladder: two run-walk steps, but one continuous step,
    /// 5 minutes, at a time.
    static let maxRunWalkJump = 2
    static let maxContinuousJump = 1
    /// The 5K finale needs a long run within 10 minutes of it: the top step or the two below.
    static let finaleReach = 2

    let rungs: [Rung]

    /// Continuous rungs run from 20 minutes to the top: the 5K time at `easyPace`, rounded to
    /// the nearest 5 minutes and kept within 30 to 45.
    init(easyPace: Int) {
        let fiveKMinutes = Double(easyPace) * Pace.miles(fromMeters: RaceDistance.fiveK.meters) / 60
        let rounded = Int((fiveKMinutes / Double(Self.continuousStepMinutes)).rounded()) * Self.continuousStepMinutes
        let top = min(max(rounded, Self.topMinutesRange.lowerBound), Self.topMinutesRange.upperBound)
        let continuous = stride(from: Self.firstContinuousMinutes, through: top, by: Self.continuousStepMinutes)
        rungs = Self.runWalkRungs.map(Rung.runWalk) + continuous.map { Rung.continuous(minutes: $0) }
    }

    var top: Int { rungs.count - 1 }

    /// Whether a plan that got to `step` ends with the 5K without walking.
    func reachesFinale(_ step: Int) -> Bool {
        step >= top - Self.finaleReach
    }

    /// The rung a runner starts on, or nil when the beginner plan is not for them.
    static func startStep(for fitness: Fitness) -> Int? {
        switch fitness {
        case .newRunner: return 0
        case .runsFiveMinutes: return 3
        case .runsTwentyMinutes, .recentRace: return nil
        }
    }

    /// The step of each week in `kinds`. Build weeks spread evenly from `first` to the top,
    /// moving at most `maxRunWalkJump` or `maxContinuousJump` a week; cutback and final weeks
    /// repeat the last build week, or `first` before any.
    func steps(for kinds: [WeekKind], first: Int) -> [Int] {
        let buildCount = kinds.filter { $0 == .build }.count
        var build: [Int] = []
        var previous = first
        for index in 0..<buildCount {
            let even = buildCount == 1
                ? first
                : first + Scaling.round(index, times: top - first, over: buildCount - 1)
            let jump: Int
            if case .continuous = rungs[previous] {
                jump = Self.maxContinuousJump
            } else {
                jump = Self.maxRunWalkJump
            }
            let step = index == 0 ? first : min(even, previous + jump)
            build.append(step)
            previous = step
        }

        var result: [Int] = []
        var nextBuild = build.makeIterator()
        var last = first
        for kind in kinds {
            if kind == .build, let step = nextBuild.next() {
                last = step
            }
            result.append(last)
        }
        return result
    }
}
