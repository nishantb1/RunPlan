import XCTest
@testable import RunCore

final class RunStatsTests: XCTestCase {

    private func run(_ month: Int, _ day: Int, miles: Double, minutes: Int) -> RunRecord {
        var start = TestCalendar.date(2026, month, day)
        start.addTimeInterval(8 * 3600)
        return RunRecord(
            mode: .outdoor,
            startedAt: start,
            durationSeconds: minutes * 60,
            distanceMeters: Pace.meters(fromMiles: miles)
        )
    }

    private lazy var runs = [
        run(10, 30, miles: 4, minutes: 40),
        run(11, 3, miles: 2, minutes: 20),
        run(11, 5, miles: 3, minutes: 33),
        run(11, 16, miles: 1, minutes: 9),
        run(11, 17, miles: 0, minutes: 25),
    ]

    func testWeeklyTotalsIncludeEmptyWeeks() {
        let weeks = RunStats.weeklyTotals(runs, weeks: 3, endingOn: TestCalendar.date(2026, 11, 18), calendar: TestCalendar.utc)
        XCTAssertEqual(weeks.map(\.weekStart), [
            TestCalendar.date(2026, 11, 2), TestCalendar.date(2026, 11, 9), TestCalendar.date(2026, 11, 16),
        ])
        XCTAssertEqual(weeks.map { (Pace.miles(fromMeters: $0.meters) * 1000).rounded() / 1000 }, [5, 0, 1])
        XCTAssertEqual(weeks.map(\.runs), [2, 0, 2])
    }

    func testPaceTrendSkipsRunsWithoutDistance() {
        XCTAssertEqual(RunStats.paceTrend(runs, limit: 2).map(\.secondsPerMile), [660, 540])
        XCTAssertEqual(RunStats.paceTrend(runs, limit: 10).map(\.secondsPerMile), [600, 600, 660, 540])
    }

    func testLongestRun() {
        XCTAssertEqual(RunStats.longestRun(runs)?.distanceMeters, Pace.meters(fromMiles: 4))
        XCTAssertNil(RunStats.longestRun([run(11, 17, miles: 0, minutes: 25)]))
    }

    func testPlanProgressCountsCompletedWorkouts() {
        var plan = PlanGenerator.generate(makeProfile(), calendar: TestCalendar.utc)
        plan.markCompleted(workoutID: plan.weeks[0].workouts[0].id, recordID: UUID())
        plan.markCompleted(workoutID: plan.weeks[0].workouts[1].id, recordID: UUID())
        let progress = PlanProgress(plan: plan)
        XCTAssertEqual(progress.completed, 2)
        XCTAssertEqual(progress.total, 24)
        XCTAssertEqual(progress.fraction, 2.0 / 24.0, accuracy: 1e-9)
    }
}
