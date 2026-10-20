import Foundation

/// The beginner 5K plan, for new runners and 5-minute runners aiming at a 5K. Each week is built
/// from one `BeginnerLadder` step:
///
/// - Build weeks spread the ladder over the plan; cutback weeks repeat the last build step.
/// - The first run day is the main session at the step, the last is the long session (one
///   extra repeat, or 5 more minutes), and any others are recovery sessions (the step below, or
///   two thirds of the minutes). At a continuous step with 3 or more run days, even-numbered
///   build weeks swap the main session for quicker intervals.
/// - The final week's last run day is the 5K without walking once the long run is within 10
///   minutes of it, and the long session at the last step otherwise.
///
/// A run that felt too hard holds the plan at its step: see `holdingStep(after:in:calendar:)`.
extension PlanGenerator {
    static let minimumRecoveryMinutes = 15
    static let longRunExtraMinutes = 5

    /// The first ladder step of a beginner plan, or nil when the profile gets the standard plan.
    static func beginnerStart(for profile: Profile) -> Int? {
        guard profile.goal.distance == .fiveK else { return nil }
        return BeginnerLadder.startStep(for: profile.fitness)
    }

    /// Weeks `numbers` of a beginner plan, whose first build week among them is at step `first`.
    /// `paceOffset` shifts the run paces, as `Plan.paceOffset` does, but not the ladder, so
    /// steps keep their meaning when a plan is rebuilt.
    static func beginnerWeeks(_ numbers: ClosedRange<Int>, first: Int, profile: Profile, paceOffset: Int = 0, calendar: Calendar) -> [Week] {
        let generated = PaceCalculator.paces(goal: profile.goal, fitness: profile.fitness)
        let builder = WorkoutBuilder(paces: generated.shifted(by: paceOffset), goal: profile.goal)
        let ladder = BeginnerLadder(easyPace: generated.easy)
        let start = calendar.startOfDay(for: profile.startDate)
        let kinds = numbers.map { weekKind($0, of: profile.planWeeks) }
        let steps = ladder.steps(for: kinds, first: first)

        return numbers.enumerated().map { offset, number in
            let kind = kinds[offset]
            let rung = ladder.rungs[steps[offset]]
            let below = ladder.rungs[max(steps[offset] - 1, 0)]
            let days = runDays(inWeek: number, from: start, profile: profile, calendar: calendar)
            let workouts: [Workout]
            if kind == .taper {
                workouts = taperRoles(days).map { day in
                    guard day.role == .long else { return recovery(rung, below: below, builder, on: day.date) }
                    return ladder.reachesFinale(steps[offset])
                        ? builder.nonStopRun(on: day.date)
                        : long(rung, builder, on: day.date)
                }
            } else {
                let quicker: Bool
                if case .continuous = rung {
                    quicker = kind == .build && days.count >= 3 && number.isMultiple(of: 2)
                } else {
                    quicker = false
                }
                workouts = days.map { day in
                    switch day.role {
                    case .quality:
                        return quicker ? builder.quickerIntervals(on: day.date) : main(rung, builder, on: day.date)
                    case .easy:
                        return recovery(rung, below: below, builder, on: day.date)
                    case .long:
                        return kind == .build ? long(rung, builder, on: day.date) : main(rung, builder, on: day.date)
                    }
                }
            }
            return Week(number: number, kind: kind, workouts: workouts, ladderStep: steps[offset])
        }
    }

    /// After a run in a beginner plan felt too hard: every later week is rebuilt so the next
    /// build week repeats the run's step, and the rest of the ladder is spread over the weeks
    /// left. The end date does not move. Weeks holding a completed run are kept as they are, and
    /// a run in the final week or outside a beginner plan changes nothing.
    public static func holdingStep(after workoutID: UUID, in plan: Plan, calendar: Calendar = .current) -> Plan {
        guard let index = plan.weeks.firstIndex(where: { $0.workouts.contains { $0.id == workoutID } }),
              let step = plan.weeks[index].ladderStep,
              plan.weeks[index].kind != .taper,
              let last = plan.weeks.last,
              index + 1 < plan.weeks.count else {
            return plan
        }
        let rebuilt = beginnerWeeks(plan.weeks[index + 1].number...last.number, first: step, profile: plan.profile,
                                    paceOffset: plan.paceOffset, calendar: calendar)
        var result = plan
        for (offset, week) in rebuilt.enumerated() {
            let position = index + 1 + offset
            guard !plan.weeks[position].workouts.contains(where: { $0.recordID != nil }) else { continue }
            result.weeks[position] = week
        }
        return result
    }

    private static func main(_ rung: BeginnerLadder.Rung, _ builder: WorkoutBuilder, on date: Date) -> Workout {
        switch rung {
        case .runWalk(let level): return builder.walkRun(level, extraRep: false, on: date)
        case .continuous(let minutes): return builder.walkedRun(minutes: minutes, kind: .easy, on: date)
        }
    }

    private static func long(_ rung: BeginnerLadder.Rung, _ builder: WorkoutBuilder, on date: Date) -> Workout {
        switch rung {
        case .runWalk(let level): return builder.walkRun(level, extraRep: true, on: date)
        case .continuous(let minutes): return builder.walkedRun(minutes: minutes + longRunExtraMinutes, kind: .longRun, on: date)
        }
    }

    private static func recovery(_ rung: BeginnerLadder.Rung, below: BeginnerLadder.Rung, _ builder: WorkoutBuilder, on date: Date) -> Workout {
        switch rung {
        case .runWalk:
            return main(below, builder, on: date)
        case .continuous(let minutes):
            let easy = max(minimumRecoveryMinutes, Scaling.round(minutes, times: 2, over: 3))
            return builder.walkedRun(minutes: easy, kind: .easy, on: date)
        }
    }
}
