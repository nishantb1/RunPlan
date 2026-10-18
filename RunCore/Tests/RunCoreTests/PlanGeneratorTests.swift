import XCTest
@testable import RunCore

final class PlanGeneratorTests: XCTestCase {

    private func generate(_ profile: Profile) -> Plan {
        PlanGenerator.generate(profile, calendar: TestCalendar.utc)
    }

    func testTwentyMinuteRunnerPlan() {
        let plan = generate(makeProfile())
        let easy = 810, tempo = 720, interval = 660

        XCTAssertEqual(plan.weeks.map(\.kind), [.build, .build, .build, .cutback, .build, .build, .build, .taper])

        let week1 = plan.weeks[0].workouts
        XCTAssertEqual(week1.map(\.date), [TestCalendar.date(2026, 11, 3), TestCalendar.date(2026, 11, 5), TestCalendar.date(2026, 11, 7)])
        XCTAssertEqual(week1.map(\.kind), [.intervals, .easy, .longRun])
        XCTAssertEqual(shapes(week1[0]), [
            StepShape(.warmup, .time(seconds: 330), pace: easy),
            StepShape(.run, .time(seconds: 120), pace: interval, group: 1, count: 3),
            StepShape(.recovery, .time(seconds: 90), pace: easy, group: 1, count: 3),
            StepShape(.cooldown, .time(seconds: 240), pace: easy),
        ])
        XCTAssertEqual(shapes(week1[1]), [StepShape(.run, .time(seconds: 1200), pace: easy)])
        XCTAssertEqual(shapes(week1[2]), [StepShape(.run, .time(seconds: 1800), pace: easy)])

        let week2 = plan.weeks[1].workouts
        XCTAssertEqual(week2.map(\.kind), [.tempo, .easy, .longRun])
        XCTAssertEqual(shapes(week2[0]), [
            StepShape(.warmup, .time(seconds: 420), pace: easy),
            StepShape(.run, .time(seconds: 660), pace: tempo),
            StepShape(.cooldown, .time(seconds: 240), pace: easy),
        ])
        XCTAssertEqual(plannedSeconds(week2[2]), 1980)

        let cutback = plan.weeks[3].workouts
        XCTAssertEqual(cutback.map(\.kind), [.tempo, .easy, .longRun])
        XCTAssertEqual(cutback.map(plannedSeconds), [1080, 1080, 1620])

        let taper = plan.weeks[7].workouts
        XCTAssertEqual(taper.map(\.date), [TestCalendar.date(2026, 12, 22), TestCalendar.date(2026, 12, 24), TestCalendar.date(2026, 12, 26)])
        XCTAssertEqual(taper.map(\.kind), [.easy, .easy, .timeTrial])
        XCTAssertEqual(plannedSeconds(taper[0]), 1080)
        XCTAssertEqual(shapes(taper[2]), [
            StepShape(.warmup, .time(seconds: 600), pace: easy),
            StepShape(.run, .distance(meters: 5000)),
            StepShape(.cooldown, .time(seconds: 300), pace: easy),
        ])
    }

    func testNewRunnerClimbsWalkRunLadderThenRuns() {
        let plan = generate(makeProfile(fitness: .newRunner, weeks: 12))

        XCTAssertEqual(shapes(plan.weeks[0].workouts[0]), [
            StepShape(.warmup, .time(seconds: 300)),
            StepShape(.run, .time(seconds: 60), group: 1, count: 8),
            StepShape(.walk, .time(seconds: 90), group: 1, count: 8),
            StepShape(.cooldown, .time(seconds: 300)),
        ])
        XCTAssertEqual(plan.weeks[0].workouts[2].steps[1].repeatCount, 9)

        // Week 4 is a cutback and repeats week 3's rung.
        XCTAssertEqual(shapes(plan.weeks[3].workouts[0]), shapes(plan.weeks[2].workouts[0]))

        for week in plan.weeks[0..<9] {
            XCTAssertEqual(Set(week.workouts.map(\.kind)), [.walkRun], "week \(week.number)")
        }
        XCTAssertEqual(plan.weeks[9].workouts.map(\.kind), [.intervals, .easy, .longRun])
        XCTAssertEqual(plan.weeks[11].workouts.map(\.kind), [.easy, .easy, .timeTrial])
        XCTAssertEqual(plan.weeks[11].workouts[2].steps[0].measure, .time(seconds: 600))
    }

    func testFiveMinuteRunnerStartsMidLadder() {
        let plan = generate(makeProfile(goal: Goal(distance: .tenK), fitness: .runsFiveMinutes, runDays: [.wednesday, .sunday], weeks: 6))

        XCTAssertEqual(plan.weeks[0].workouts[0].steps[1].measure, .time(seconds: 240))
        XCTAssertEqual(plan.weeks[0].workouts[0].steps[1].repeatCount, 5)
        XCTAssertEqual(plan.weeks[3].workouts.map(\.kind), [.intervals, .longRun])
        XCTAssertEqual(plan.weeks[3].workouts.map(plannedSeconds), [960, 1380])
        XCTAssertEqual(plan.weeks[5].workouts.map(\.kind), [.easy, .timeTrial])
        XCTAssertEqual(plan.weeks[5].workouts[1].steps[1].measure, .distance(meters: 10000))
    }

    func testEveryProfileGivesAValidPlan() {
        let goals = [
            Goal(distance: .fiveK),
            Goal(distance: .fiveK, targetSeconds: 1500),
            Goal(distance: .tenK),
            Goal(distance: .tenK, targetSeconds: 3300),
        ]
        let fitnesses: [Fitness] = [.newRunner, .runsFiveMinutes, .runsTwentyMinutes, .recentRace(distance: .fiveK, seconds: 1800)]
        let daySets: [[Weekday]] = [
            [.tuesday, .saturday],
            [.tuesday, .thursday, .saturday],
            [.monday, .wednesday, .friday, .sunday],
            [.monday, .tuesday, .thursday, .saturday, .sunday],
        ]

        for goal in goals {
            for fitness in fitnesses {
                for days in daySets {
                    for weeks in Profile.planWeeksRange {
                        let profile = makeProfile(goal: goal, fitness: fitness, runDays: days, weeks: weeks)
                        checkValid(generate(profile), profile: profile, label: "\(goal) \(fitness) \(days.count)d \(weeks)w")
                    }
                }
            }
        }
    }

    func testSameProfileGivesSamePlan() {
        let profile = makeProfile(goal: Goal(distance: .tenK, targetSeconds: 3300), fitness: .recentRace(distance: .tenK, seconds: 3500), weeks: 12)
        let first = generate(profile).weeks.flatMap(\.workouts)
        let second = generate(profile).weeks.flatMap(\.workouts)
        XCTAssertEqual(first.map(\.date), second.map(\.date))
        XCTAssertEqual(first.map(\.title), second.map(\.title))
        XCTAssertEqual(first.map(shapes), second.map(shapes))
    }

    func testStartDateMidWeekKeepsRolesByWeekday() {
        var profile = makeProfile()
        profile.startDate = TestCalendar.date(2026, 11, 4) // a Wednesday
        let week1 = generate(profile).weeks[0].workouts
        XCTAssertEqual(week1.map(\.date), [TestCalendar.date(2026, 11, 5), TestCalendar.date(2026, 11, 7), TestCalendar.date(2026, 11, 10)])
        XCTAssertEqual(week1.map(\.kind), [.easy, .longRun, .intervals])
    }

    func testDatesStayAtMidnightAcrossDaylightSavingChange() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        var profile = makeProfile()
        profile.startDate = calendar.date(from: DateComponents(year: 2026, month: 10, day: 26))!
        let workouts = PlanGenerator.generate(profile, calendar: calendar).weeks.flatMap(\.workouts)
        XCTAssertEqual(workouts.count, 24)
        for workout in workouts {
            XCTAssertEqual(workout.date, calendar.startOfDay(for: workout.date))
            XCTAssertTrue(profile.runDays.contains(Weekday(of: workout.date, calendar: calendar)))
        }
    }

    // MARK: - Invariants

    private func checkValid(_ plan: Plan, profile: Profile, label: String) {
        let calendar = TestCalendar.utc
        let start = calendar.startOfDay(for: profile.startDate)
        XCTAssertEqual(plan.weeks.map(\.number), Array(1...profile.planWeeks), label)

        var previousBuildSeconds: Int?
        for week in plan.weeks {
            let context = "\(label) week \(week.number)"
            let expectedKind: WeekKind = week.number == profile.planWeeks ? .taper
                : week.number.isMultiple(of: 4) ? .cutback : .build
            XCTAssertEqual(week.kind, expectedKind, context)

            let windowStart = calendar.date(byAdding: .day, value: (week.number - 1) * 7, to: start)!
            let windowEnd = calendar.date(byAdding: .day, value: 7, to: windowStart)!
            XCTAssertEqual(week.workouts.count, profile.daysPerWeek, context)
            XCTAssertEqual(week.workouts.map(\.date), week.workouts.map(\.date).sorted(), context)
            for workout in week.workouts {
                XCTAssertTrue(workout.date >= windowStart && workout.date < windowEnd, context)
                XCTAssertTrue(profile.runDays.contains(Weekday(of: workout.date, calendar: calendar)), context)
                for step in workout.steps {
                    switch step.measure {
                    case .time(let seconds): XCTAssertGreaterThan(seconds, 0, context)
                    case .distance(let meters): XCTAssertGreaterThan(meters, 0, context)
                    }
                    if workout.kind == .walkRun {
                        XCTAssertNil(step.targetPaceSecondsPerMile, context)
                    }
                }
            }

            let kinds = week.workouts.map(\.kind)
            let running = !kinds.contains(.walkRun)
            if week.kind != .taper {
                XCTAssertFalse(kinds.contains(.timeTrial), context)
                if running {
                    XCTAssertEqual(kinds.filter { $0 == .longRun }.count, 1, context)
                    XCTAssertLessThanOrEqual(kinds.filter { $0 == .intervals || $0 == .tempo }.count, 1, context)
                }
            }

            guard running, week.kind != .taper else { continue }
            let seconds = week.workouts.map(plannedSeconds).reduce(0, +)
            let slack = 60 * profile.daysPerWeek
            if week.kind == .build {
                if let previous = previousBuildSeconds {
                    XCTAssertLessThanOrEqual(Double(seconds), Double(previous) * 1.1 + Double(slack), "\(context) grew from \(previous) to \(seconds)")
                }
                previousBuildSeconds = seconds
            } else if let previous = previousBuildSeconds {
                XCTAssertLessThanOrEqual(Double(seconds), Double(previous) * 0.8 + Double(slack), "\(context) cutback \(seconds) after \(previous)")
            }
        }

        let all = plan.weeks.flatMap(\.workouts)
        XCTAssertEqual(all.filter { $0.kind == .timeTrial }.count, 1, label)
        let last = plan.weeks.last?.workouts.last
        XCTAssertEqual(last?.kind, .timeTrial, label)
        XCTAssertEqual(last?.steps.map(\.measure).contains(.distance(meters: profile.goal.distance.meters)), true, label)
    }
}
