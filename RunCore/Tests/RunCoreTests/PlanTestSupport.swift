import Foundation
@testable import RunCore

/// A step without its random ID, so generated steps can be compared with expected ones.
struct StepShape: Equatable, CustomStringConvertible {
    var kind: StepKind
    var measure: StepMeasure
    var pace: Int?
    var group: Int?
    var count: Int?

    init(_ kind: StepKind, _ measure: StepMeasure, pace: Int? = nil, group: Int? = nil, count: Int? = nil) {
        self.kind = kind
        self.measure = measure
        self.pace = pace
        self.group = group
        self.count = count
    }

    init(_ step: Step) {
        self.init(step.kind, step.measure, pace: step.targetPaceSecondsPerMile, group: step.repeatGroup, count: step.repeatCount)
    }

    var description: String {
        "\(kind) \(measure) pace:\(pace.map(String.init) ?? "-") group:\(group.map(String.init) ?? "-") count:\(count.map(String.init) ?? "-")"
    }
}

func shapes(_ workout: Workout) -> [StepShape] {
    workout.steps.map { StepShape($0) }
}

/// Planned seconds of a workout's timed steps after repeats are expanded. Distance steps count as zero.
func plannedSeconds(_ workout: Workout) -> Int {
    StepExpander.expand(workout.steps).compactMap(\.durationSeconds).reduce(0, +)
}

enum TestCalendar {
    static var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    static func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        utc.date(from: DateComponents(year: year, month: month, day: day))!
    }
}

/// A profile starting Monday 2 November 2026. Defaults: 5K to finish, runs 20 minutes,
/// Tuesday, Thursday and Saturday, 8 weeks.
func makeProfile(
    goal: Goal = Goal(distance: .fiveK),
    fitness: Fitness = .runsTwentyMinutes,
    runDays: [Weekday] = [.tuesday, .thursday, .saturday],
    weeks: Int = 8
) -> Profile {
    Profile(goal: goal, fitness: fitness, runDays: runDays, planWeeks: weeks, startDate: TestCalendar.date(2026, 11, 2))
}
