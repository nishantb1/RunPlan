import XCTest
@testable import RunCore

final class PaceInsightTests: XCTestCase {

    /// An 8-week beginner plan: easy pace 810 (4.4 mph), walks 1200 (3.0 mph). Week 1's sessions
    /// are 5:00 walk, 8 or 9 × (1:00 run, 1:30 walk), 5:00 walk.
    private func beginnerPlan() -> Plan {
        PlanGenerator.generate(makeProfile(fitness: .newRunner, weeks: 8), calendar: TestCalendar.utc)
    }

    private func day(_ offset: Int) -> Date {
        TestCalendar.date(2026, 11, 3).addingTimeInterval(Double(offset) * 86_400)
    }

    /// Which `day` a date is.
    private func index(of date: Date) -> Int {
        Int((date.timeIntervalSince(day(0)) / 86_400).rounded())
    }

    /// An outdoor record whose run steps went at `pace`: 8 minutes of running.
    private func outdoor(_ workout: Workout, pace: Int, on date: Date, feeling: Feeling? = nil) -> RunRecord {
        RunRecord(workoutID: workout.id, mode: .outdoor, startedAt: date, durationSeconds: plannedSeconds(workout),
                  distanceMeters: 3000, feeling: feeling, runSeconds: 480, runMeters: Pace.meters(fromMiles: 480 / Double(pace)))
    }

    /// Completes the first `count` workouts with records from `make`, oldest first.
    private func complete(_ plan: inout Plan, _ count: Int, _ make: (Workout, Date) -> RunRecord) -> [RunRecord] {
        Array(plan.workouts.prefix(count)).enumerated().map { offset, workout in
            let record = make(workout, day(offset))
            plan.markCompleted(workoutID: workout.id, recordID: record.id)
            return record
        }
    }

    func testTargetIsTheRunStepsCombinedPace() {
        let plan = beginnerPlan()
        XCTAssertEqual(PaceInsight.target(of: plan.workouts[0]), 810)
        // The 5K finale's distance step counts at its target.
        XCTAssertEqual(PaceInsight.target(of: plan.workouts.last!), 810)
        XCTAssertNil(PaceInsight.target(of: Workout(date: day(0), kind: .easy, title: "Free", steps: [Step(kind: .run, measure: .open)])))
    }

    func testThreeFastOutdoorRunsSuggestFasterCappedAt30() {
        var plan = beginnerPlan()
        let records = complete(&plan, 3) { outdoor($0, pace: 760, on: $1) }
        XCTAssertEqual(PaceInsight.suggestion(for: plan, records: records),
                       PaceSuggestion(change: -30, currentEasy: 810, reason: .ranFaster))
    }

    func testMedianOffsetRoundedToFive() {
        var plan = beginnerPlan()
        let paces = [832, 838, 851] // 22, 28 and 41 s/mi slow: median 28 rounds to 30, 22 would give 20
        let records = complete(&plan, 3) { workout, date in
            outdoor(workout, pace: paces[index(of: date)], on: date)
        }
        XCTAssertEqual(PaceInsight.suggestion(for: plan, records: records)?.change, 30)
        XCTAssertEqual(PaceInsight.suggestion(for: plan, records: records)?.reason, .ranSlower)
    }

    func testNoSuggestionWhenRunsDisagreeOrAreTooFew() {
        var plan = beginnerPlan()
        let paces = [760, 860, 760]
        let mixed = complete(&plan, 3) { workout, date in
            outdoor(workout, pace: paces[index(of: date)], on: date)
        }
        XCTAssertNil(PaceInsight.suggestion(for: plan, records: mixed))

        var fresh = beginnerPlan()
        let two = complete(&fresh, 2) { outdoor($0, pace: 760, on: $1) }
        XCTAssertNil(PaceInsight.suggestion(for: fresh, records: two))

        // Within 15 s/mi is on target.
        var close = beginnerPlan()
        let near = complete(&close, 3) { outdoor($0, pace: 800, on: $1) }
        XCTAssertNil(PaceInsight.suggestion(for: close, records: near))
    }

    func testTreadmillRunsMeasuredFromTypedDistance() {
        var plan = beginnerPlan()
        let records = complete(&plan, 3) { workout, date in
            // Walks at their 3.0 mph target, runs at 790 s/mi.
            let flat = StepExpander.expand(workout.steps)
            let runSeconds = flat.filter { $0.kind == .run }.compactMap(\.durationSeconds).reduce(0, +)
            let walkSeconds = flat.filter { $0.kind != .run }.compactMap(\.durationSeconds).reduce(0, +)
            let miles = Double(runSeconds) / 790 + Double(walkSeconds) / 1200
            return RunRecord(workoutID: workout.id, mode: .treadmill, startedAt: date, durationSeconds: runSeconds + walkSeconds,
                             distanceMeters: Pace.meters(fromMiles: miles))
        }
        XCTAssertEqual(PaceInsight.offset(of: records[0], against: plan.workouts[0]), -20)
        XCTAssertEqual(PaceInsight.suggestion(for: plan, records: records),
                       PaceSuggestion(change: -20, currentEasy: 810, reason: .ranFaster))
    }

    func testTreadmillRunEndedEarlyOrWithoutDistanceDoesNotCount() {
        let workout = beginnerPlan().workouts[0]
        let short = RunRecord(workoutID: workout.id, mode: .treadmill, startedAt: day(0), durationSeconds: 600, distanceMeters: 2000)
        XCTAssertNil(PaceInsight.offset(of: short, against: workout))
        let noDistance = RunRecord(workoutID: workout.id, mode: .treadmill, startedAt: day(0), durationSeconds: 1800, distanceMeters: 0)
        XCTAssertNil(PaceInsight.offset(of: noDistance, against: workout))
    }

    func testTwoRunsThatFeltEasySuggestALittleFaster() {
        var plan = beginnerPlan()
        let easy = complete(&plan, 2) { workout, date in
            RunRecord(workoutID: workout.id, mode: .treadmill, startedAt: date, durationSeconds: 1800, distanceMeters: 0, feeling: .tooEasy)
        }
        XCTAssertEqual(PaceInsight.suggestion(for: plan, records: easy),
                       PaceSuggestion(change: -15, currentEasy: 810, reason: .feltEasy))

        var other = beginnerPlan()
        let feelings: [Feeling] = [.tooHard, .justRight]
        let mixed = complete(&other, 2) { workout, date in
            let index = index(of: date)
            return RunRecord(workoutID: workout.id, mode: .treadmill, startedAt: date, durationSeconds: 1800, distanceMeters: 0, feeling: feelings[index])
        }
        XCTAssertNil(PaceInsight.suggestion(for: other, records: mixed))
    }

    func testOnlyRunsAfterTheLastCheckCount() {
        var plan = beginnerPlan()
        let records = complete(&plan, 3) { outdoor($0, pace: 760, on: $1) }
        plan.dismissPaceSuggestion(at: day(1).addingTimeInterval(1))
        XCTAssertNil(PaceInsight.suggestion(for: plan, records: records))
    }

    func testApplyingShiftsRunTargetsOfUndoneWorkoutsAndSurvivesARebuild() {
        var plan = beginnerPlan()
        plan.markCompleted(workoutID: plan.workouts[0].id, recordID: UUID())
        let done = plan.workouts[0]
        plan.applyPaceChange(-30, at: day(1))

        XCTAssertEqual(plan.paceOffset, -30)
        XCTAssertEqual(plan.paceCheckedAt, day(1))
        XCTAssertEqual(plan.workouts[0], done)
        XCTAssertEqual(plan.workouts[1].steps.map(\.targetPaceSecondsPerMile), [1200, 780, 1200, 1200])
        XCTAssertEqual(plan.workouts.last?.steps.map(\.targetPaceSecondsPerMile), [1200, 780, 1200])

        // Holding a step rebuilds later weeks with the change kept and the same ladder.
        let held = PlanGenerator.holdingStep(after: plan.workouts[1].id, in: plan, calendar: TestCalendar.utc)
        XCTAssertEqual(held.weeks[1].workouts[0].steps[1].targetPaceSecondsPerMile, 780)
        XCTAssertEqual(held.weeks.map(\.ladderStep), [0, 0, 2, 2, 4, 6, 7, 7])
        XCTAssertEqual(held.paceOffset, -30)
    }

    func testOlderPlansStillLoad() throws {
        let plan = beginnerPlan()
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(plan)) as? [String: Any])
        json["paceOffset"] = nil
        json["paceCheckedAt"] = nil
        XCTAssertEqual(try JSONDecoder().decode(Plan.self, from: JSONSerialization.data(withJSONObject: json)), plan)
    }

    // MARK: - Run portion

    func testOutdoorTrackerTimesOnlyTheRunSteps() throws {
        let engine = WorkoutEngine(planSteps: [
            Step(kind: .walk, measure: .time(seconds: 60)),
            Step(kind: .run, measure: .time(seconds: 60)),
            Step(kind: .walk, measure: .time(seconds: 60)),
        ])
        engine.start(now: trackStart)
        var tracker = OutdoorTracker()
        for second in 0...179 {
            let now = trackStart.addingTimeInterval(Double(second))
            // 1.5 m/s walking, 3 m/s running.
            let north = second <= 60 ? 1.5 * Double(second) : second <= 120 ? 90 + 3 * Double(second - 60) : 270 + 1.5 * Double(second - 120)
            tracker.record(fix(at: Double(second), north: north), now: now, counting: true)
            _ = tracker.events(for: try XCTUnwrap(engine.snapshot(now: now)), now: now)
        }
        XCTAssertEqual(tracker.runSeconds, 60)
        XCTAssertEqual(try XCTUnwrap(tracker.runMeters), 180, accuracy: 4)
    }
}

final class FollowUpTests: XCTestCase {

    private func finishedPlan(finaleSeconds: Int?) -> (Plan, [RunRecord]) {
        var plan = PlanGenerator.generate(makeProfile(fitness: .newRunner, weeks: 8), calendar: TestCalendar.utc)
        guard let seconds = finaleSeconds, let finale = plan.workouts.last else { return (plan, []) }
        // 5:00 walking warm-up and cool-down around the 5K.
        let record = RunRecord(workoutID: finale.id, mode: .outdoor, startedAt: finale.date, durationSeconds: seconds + 600, distanceMeters: 5300)
        plan.markCompleted(workoutID: finale.id, recordID: record.id)
        return (plan, [record])
    }

    func testFinaleTimeLeavesOutTheWalking() {
        let (plan, records) = finishedPlan(finaleSeconds: 2520)
        XCTAssertEqual(FollowUp.finaleSeconds(of: plan, records: records), 2520)
    }

    func testNoFinaleTimeWhenNotRunOrImplausible() {
        let (plan, _) = finishedPlan(finaleSeconds: nil)
        XCTAssertNil(FollowUp.finaleSeconds(of: plan, records: []))
        let (ended, records) = finishedPlan(finaleSeconds: 300) // 5K in 5 minutes
        XCTAssertNil(FollowUp.finaleSeconds(of: ended, records: records))
    }

    func testFollowUpProfiles() {
        let (plan, _) = finishedPlan(finaleSeconds: nil)
        let start = TestCalendar.date(2027, 1, 4)

        let faster = FollowUp.profile(after: plan, distance: .fiveK, finaleSeconds: 2520, start: start)
        XCTAssertEqual(faster.goal, Goal(distance: .fiveK))
        XCTAssertEqual(faster.fitness, .recentRace(distance: .fiveK, seconds: 2520))
        XCTAssertEqual(faster.planWeeks, 8)
        XCTAssertEqual(faster.runDays, plan.profile.runDays)
        XCTAssertEqual(faster.startDate, start)

        let tenK = FollowUp.profile(after: plan, distance: .tenK, finaleSeconds: nil, start: start)
        XCTAssertEqual(tenK.goal, Goal(distance: .tenK))
        XCTAssertEqual(tenK.fitness, .runsTwentyMinutes)
        XCTAssertEqual(tenK.planWeeks, 10)

        // A follow-up from a race time gets the standard plan.
        XCTAssertNil(PlanGenerator.generate(faster, calendar: TestCalendar.utc).weeks[0].ladderStep)
    }
}
