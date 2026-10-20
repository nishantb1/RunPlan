import XCTest
@testable import RunCore

final class BeginnerPlanTests: XCTestCase {

    private func generate(_ profile: Profile) -> Plan {
        PlanGenerator.generate(profile, calendar: TestCalendar.utc)
    }

    private func beginner(_ fitness: Fitness = .newRunner, weeks: Int, days: [Weekday] = [.tuesday, .thursday, .saturday]) -> Plan {
        generate(makeProfile(fitness: fitness, runDays: days, weeks: weeks))
    }

    // MARK: - Ladder

    func testLadderTopIsTheFiveKAtEasyPaceWithinBounds() {
        func topMinutes(_ easyPace: Int) -> Int? {
            guard case .continuous(let minutes) = BeginnerLadder(easyPace: easyPace).rungs.last else { return nil }
            return minutes
        }
        XCTAssertEqual(topMinutes(TrainingPaces.defaults.easy), 40) // 13:30 /mi: 5K in 41.9 min
        XCTAssertEqual(topMinutes(573), 30) // 29.7 min
        XCTAssertEqual(topMinutes(1000), 45) // 51.8 min, capped
        XCTAssertEqual(BeginnerLadder(easyPace: 810).rungs.count, 11)
    }

    func testRunningTimeNeverDropsUpTheLadder() {
        let running = BeginnerLadder(easyPace: 810).rungs.map { rung -> Int in
            switch rung {
            case .runWalk(let level): return level.runSeconds * level.repeats
            case .continuous(let minutes): return minutes * 60
            }
        }
        XCTAssertEqual(running, running.sorted())
    }

    func testStartSteps() {
        XCTAssertEqual(BeginnerLadder.startStep(for: .newRunner), 0)
        XCTAssertEqual(BeginnerLadder.startStep(for: .runsFiveMinutes), 3)
        XCTAssertNil(BeginnerLadder.startStep(for: .runsTwentyMinutes))
        XCTAssertNil(BeginnerLadder.startStep(for: .recentRace(distance: .fiveK, seconds: 1800)))
    }

    func testStepsSpreadWithCappedJumps() {
        let ladder = BeginnerLadder(easyPace: 810)
        let eight: [WeekKind] = [.build, .build, .build, .cutback, .build, .build, .build, .taper]
        // Two run-walk steps a week at most, then one continuous step (5 minutes) a week.
        XCTAssertEqual(ladder.steps(for: eight, first: 0), [0, 2, 4, 4, 6, 7, 8, 8])
        XCTAssertEqual(ladder.steps(for: [.cutback, .build, .taper], first: 5), [5, 5, 5])
        XCTAssertEqual(ladder.steps(for: [.build, .build], first: 9), [9, 10])
    }

    // MARK: - Plans

    func testEightWeekNewRunnerPlan() {
        let plan = beginner(weeks: 8)
        let walk = 1200, easy = TrainingPaces.defaults.easy

        XCTAssertEqual(plan.weeks.map(\.ladderStep), [0, 2, 4, 4, 6, 7, 8, 8])
        let week1 = plan.weeks[0].workouts
        XCTAssertEqual(week1.map(\.date), [TestCalendar.date(2026, 11, 3), TestCalendar.date(2026, 11, 5), TestCalendar.date(2026, 11, 7)])
        XCTAssertEqual(week1.map(\.title), ["Run-walk · 8 × 1:00", "Run-walk · 8 × 1:00", "Run-walk · 9 × 1:00"])
        XCTAssertEqual(shapes(week1[0]), [
            StepShape(.warmup, .time(seconds: 300), pace: walk),
            StepShape(.run, .time(seconds: 60), pace: easy, group: 1, count: 8),
            StepShape(.walk, .time(seconds: 90), pace: walk, group: 1, count: 8),
            StepShape(.cooldown, .time(seconds: 300), pace: walk),
        ])

        // Main session at the step, recovery at the step below, long with an extra repeat.
        XCTAssertEqual(plan.weeks[1].workouts.map(\.title), ["Run-walk · 6 × 2:30", "Run-walk · 7 × 1:30", "Run-walk · 7 × 2:30"])
        // A cutback repeats the step without the long session's extra repeat.
        XCTAssertEqual(plan.weeks[3].workouts.map(\.title), ["Run-walk · 3 × 6:00", "Run-walk · 4 × 4:00", "Run-walk · 3 × 6:00"])
        XCTAssertEqual(plan.weeks[4].workouts.map(\.title), ["Easy run · 20 min", "Easy run · 15 min", "Long run · 25 min"])
        XCTAssertEqual(plan.weeks[4].workouts.map(\.kind), [.easy, .easy, .longRun])
        // Even-numbered continuous build weeks swap the main session for quicker intervals.
        XCTAssertEqual(plan.weeks[5].workouts.map(\.title), ["Quicker intervals · 6 × 1:00", "Easy run · 17 min", "Long run · 30 min"])
        XCTAssertEqual(plan.weeks[6].workouts.map(\.title), ["Easy run · 30 min", "Easy run · 20 min", "Long run · 35 min"])

        let final = plan.weeks[7].workouts
        XCTAssertEqual(final.map(\.title), ["Easy run · 20 min", "Easy run · 20 min", "Run 5K non-stop"])
        XCTAssertEqual(shapes(final[2]), [
            StepShape(.warmup, .time(seconds: 300), pace: walk),
            StepShape(.run, .distance(meters: 5000), pace: easy),
            StepShape(.cooldown, .time(seconds: 300), pace: walk),
        ])
        XCTAssertTrue(plan.workouts.allSatisfy(\.treadmillTargetsOnly))
    }

    func testQuickerIntervals() {
        let workout = beginner(weeks: 8).weeks[5].workouts[0]
        XCTAssertEqual(workout.kind, .intervals)
        XCTAssertEqual(shapes(workout), [
            StepShape(.warmup, .time(seconds: 300), pace: 1200),
            StepShape(.run, .time(seconds: 600), pace: 810),
            StepShape(.run, .time(seconds: 60), pace: 720, group: 1, count: 6),
            StepShape(.walk, .time(seconds: 120), pace: 1200, group: 1, count: 6),
            StepShape(.cooldown, .time(seconds: 300), pace: 1200),
        ])
    }

    func testTwoDayWeeksHaveNoQuickerIntervals() {
        let plan = beginner(.runsFiveMinutes, weeks: 8, days: [.tuesday, .saturday])
        XCTAssertEqual(plan.weeks.map(\.ladderStep), [3, 4, 6, 6, 7, 8, 9, 9])
        XCTAssertFalse(plan.workouts.contains { $0.kind == .intervals })
        XCTAssertEqual(plan.workouts.last?.title, "Run 5K non-stop")
    }

    func testPlanTooShortForTheFiveKEndsWithALongSession() {
        let plan = beginner(weeks: 6)
        XCTAssertEqual(plan.weeks.last?.ladderStep, 6)
        XCTAssertEqual(plan.workouts.last?.title, "Long run · 25 min")
    }

    func testEveryBeginnerPlanClimbsSteadilyToTheFiveK() {
        let ladder = BeginnerLadder(easyPace: TrainingPaces.defaults.easy)
        for fitness in [Fitness.newRunner, .runsFiveMinutes] {
            for days in [[Weekday.tuesday, .saturday], [.tuesday, .thursday, .saturday], [.monday, .tuesday, .thursday, .saturday, .sunday]] {
                for weeks in Profile.beginnerMinimumWeeks...Profile.planWeeksRange.upperBound {
                    let label = "\(fitness) \(days.count)d \(weeks)w"
                    let plan = beginner(fitness, weeks: weeks, days: days)
                    let steps = plan.weeks.compactMap(\.ladderStep)
                    XCTAssertEqual(steps.count, weeks, label)
                    XCTAssertEqual(steps, steps.sorted(), label)
                    for (previous, step) in zip(steps, steps.dropFirst()) {
                        let continuous = previous >= BeginnerLadder.runWalkRungs.count
                        XCTAssertLessThanOrEqual(step - previous, continuous ? 1 : 2, label)
                    }
                    XCTAssertTrue(ladder.reachesFinale(steps.last ?? 0), label)
                    XCTAssertEqual(plan.workouts.last?.title, "Run 5K non-stop", label)
                }
            }
        }
    }

    func testTenKAndTwentyMinuteRunnersKeepTheStandardPlan() {
        XCTAssertNil(generate(makeProfile(goal: Goal(distance: .tenK), fitness: .newRunner)).weeks[0].ladderStep)
        XCTAssertNil(generate(makeProfile(fitness: .runsTwentyMinutes)).weeks[0].ladderStep)
    }

    func testPlanWeeksRange() {
        XCTAssertEqual(Profile.planWeeksRange(goal: .fiveK, fitness: .newRunner), 8...16)
        XCTAssertEqual(Profile.planWeeksRange(goal: .fiveK, fitness: .runsFiveMinutes), 8...16)
        XCTAssertEqual(Profile.planWeeksRange(goal: .fiveK, fitness: .runsTwentyMinutes), 6...16)
        XCTAssertEqual(Profile.planWeeksRange(goal: .tenK, fitness: .newRunner), 6...16)
    }

    // MARK: - Holding a step

    func testTooHardHoldsTheStepAndKeepsTheEndDate() {
        var plan = beginner(weeks: 12)
        XCTAssertEqual(plan.weeks.map(\.ladderStep), [0, 1, 3, 3, 4, 5, 6, 6, 7, 8, 9, 9])
        let hard = plan.weeks[2].workouts[0]
        plan.markCompleted(workoutID: hard.id, recordID: UUID())
        let endDate = plan.workouts.last?.date

        let held = PlanGenerator.holdingStep(after: hard.id, in: plan, calendar: TestCalendar.utc)

        XCTAssertEqual(held.weeks.map(\.ladderStep), [0, 1, 3, 3, 3, 4, 6, 6, 7, 8, 9, 9])
        XCTAssertEqual(held.weeks[0...2], plan.weeks[0...2])
        XCTAssertEqual(held.weeks[4].workouts.map(\.title), plan.weeks[2].workouts.map(\.title))
        XCTAssertEqual(held.workouts.last?.date, endDate)
        XCTAssertEqual(held.workouts.last?.title, "Run 5K non-stop")
        XCTAssertEqual(held.workouts.count, plan.workouts.count)
    }

    func testHoldKeepsLaterWeeksWithACompletedRun() {
        var plan = beginner(weeks: 12)
        let hard = plan.weeks[2].workouts[0]
        plan.markCompleted(workoutID: plan.weeks[5].workouts[0].id, recordID: UUID())
        let held = PlanGenerator.holdingStep(after: hard.id, in: plan, calendar: TestCalendar.utc)
        XCTAssertEqual(held.weeks[5], plan.weeks[5])
        XCTAssertEqual(held.weeks[4].ladderStep, 3)
    }

    func testHoldChangesNothingInTheFinalWeekOrAStandardPlan() {
        let plan = beginner(weeks: 8)
        let finalRun = plan.weeks[7].workouts[0].id
        XCTAssertEqual(PlanGenerator.holdingStep(after: finalRun, in: plan, calendar: TestCalendar.utc), plan)

        let standard = generate(makeProfile())
        XCTAssertEqual(PlanGenerator.holdingStep(after: standard.weeks[0].workouts[0].id, in: standard, calendar: TestCalendar.utc), standard)
        XCTAssertEqual(PlanGenerator.holdingStep(after: UUID(), in: plan, calendar: TestCalendar.utc), plan)
    }

    // MARK: - Pushing back

    func testPushBackMovesTheRestOfTheWeek() {
        var plan = beginner(weeks: 8)
        let week1 = plan.weeks[0].workouts
        let week2 = plan.weeks[1]
        plan.pushBack(workoutID: week1[0].id, calendar: TestCalendar.utc)
        XCTAssertEqual(plan.weeks[0].workouts.map(\.id), week1.map(\.id))
        XCTAssertEqual(plan.weeks[0].workouts.map(\.date), [TestCalendar.date(2026, 11, 4), TestCalendar.date(2026, 11, 6), TestCalendar.date(2026, 11, 8)])

        // The week ends on Sunday 8 November, so its last run now falls out.
        plan.pushBack(workoutID: week1[0].id, calendar: TestCalendar.utc)
        XCTAssertEqual(plan.weeks[0].workouts.map(\.id), [week1[0].id, week1[1].id])
        XCTAssertEqual(plan.weeks[0].workouts.map(\.date), [TestCalendar.date(2026, 11, 5), TestCalendar.date(2026, 11, 7)])
        XCTAssertEqual(plan.weeks[1], week2)
    }

    func testPushBackLeavesCompletedRunsAndEarlierRuns() {
        var plan = beginner(weeks: 8)
        let week1 = plan.weeks[0].workouts
        plan.markCompleted(workoutID: week1[2].id, recordID: UUID())
        plan.pushBack(workoutID: week1[1].id, calendar: TestCalendar.utc)
        XCTAssertEqual(plan.weeks[0].workouts.map(\.date), [TestCalendar.date(2026, 11, 3), TestCalendar.date(2026, 11, 6), TestCalendar.date(2026, 11, 7)])

        let before = plan
        plan.pushBack(workoutID: week1[2].id, calendar: TestCalendar.utc)
        XCTAssertEqual(plan, before)
    }

    func testThePlansLastRunCanBePushedPastTheEnd() {
        var plan = beginner(weeks: 8)
        let last = plan.workouts.last!
        plan.pushBack(workoutID: last.id, calendar: TestCalendar.utc)
        plan.pushBack(workoutID: last.id, calendar: TestCalendar.utc)
        XCTAssertEqual(plan.workouts.last?.id, last.id)
        XCTAssertEqual(plan.workouts.last?.date, TestCalendar.date(2026, 12, 28))
    }

    // MARK: - Coding

    func testOlderWeeksAndRunsStillLoad() throws {
        var week = beginner(weeks: 8).weeks[0]
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(week)) as? [String: Any])
        json["ladderStep"] = nil
        week.ladderStep = nil
        XCTAssertEqual(try JSONDecoder().decode(Week.self, from: JSONSerialization.data(withJSONObject: json)), week)

        let record = RunRecord(mode: .treadmill, startedAt: Date(timeIntervalSince1970: 1_800_000_000), durationSeconds: 60, distanceMeters: 0, feeling: .tooHard)
        let decoded = try JSONDecoder().decode(RunRecord.self, from: JSONEncoder().encode(record))
        XCTAssertEqual(decoded.feeling, .tooHard)
    }
}
