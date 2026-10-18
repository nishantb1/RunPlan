import XCTest
@testable import RunCore

final class PlanModelTests: XCTestCase {

    private func roundTrip<T: Codable & Equatable>(_ value: T) throws -> T {
        try JSONDecoder().decode(T.self, from: JSONEncoder().encode(value))
    }

    func testProfileWithRaceResultRoundTrips() throws {
        let profile = makeProfile(
            goal: Goal(distance: .tenK, targetSeconds: 3300),
            fitness: .recentRace(distance: .fiveK, seconds: 1620),
            weeks: 10
        )
        XCTAssertEqual(try roundTrip(profile), profile)
    }

    func testJustFinishGoalRoundTrips() throws {
        let profile = makeProfile(goal: Goal(distance: .fiveK), fitness: .newRunner)
        XCTAssertNil(profile.goal.targetSeconds)
        XCTAssertEqual(try roundTrip(profile), profile)
    }

    func testRunDaysAreKeptMondayFirst() {
        let profile = makeProfile(runDays: [.sunday, .monday, .wednesday])
        XCTAssertEqual(profile.runDays, [.monday, .wednesday, .sunday])
        XCTAssertEqual(profile.daysPerWeek, 3)
    }

    func testWeekdayMatchesCalendar() {
        XCTAssertEqual(Weekday(of: TestCalendar.date(2026, 11, 2), calendar: TestCalendar.utc), .monday)
        XCTAssertEqual(Weekday(of: TestCalendar.date(2026, 11, 8), calendar: TestCalendar.utc), .sunday)
        XCTAssertEqual(Weekday.allCases.first, .monday)
        XCTAssertEqual(Weekday.allCases.last, .sunday)
        XCTAssertTrue(Weekday.saturday < .sunday)
        XCTAssertEqual(Weekday.thursday.name, "Thursday")
    }

    func testRaceDistances() {
        XCTAssertEqual(RaceDistance.fiveK.meters, 5000)
        XCTAssertEqual(RaceDistance.tenK.displayName, "10K")
    }

    func testPlanRoundTrips() throws {
        let workout = SampleWorkouts.runWalk(on: TestCalendar.date(2026, 11, 3))
        let plan = Plan(profile: makeProfile(), weeks: [Week(number: 1, kind: .build, workouts: [workout])])
        XCTAssertEqual(try roundTrip(plan), plan)
        XCTAssertEqual(plan.weeks[0].id, 1)
    }
}
