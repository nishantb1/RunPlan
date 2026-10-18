import XCTest
@testable import RunCore

final class PlanTests: XCTestCase {

    private var plan = PlanGenerator.generate(makeProfile(), calendar: TestCalendar.utc)

    private func next(on date: Date) -> Workout? {
        plan.nextWorkout(onOrAfter: date, calendar: TestCalendar.utc)
    }

    func testNextWorkoutIsFirstOnOrAfterTheDay() {
        XCTAssertEqual(next(on: TestCalendar.date(2026, 11, 2))?.date, TestCalendar.date(2026, 11, 3))
        let eveningOfTheThird = TestCalendar.date(2026, 11, 3).addingTimeInterval(18 * 3600)
        XCTAssertEqual(next(on: eveningOfTheThird)?.date, TestCalendar.date(2026, 11, 3))
    }

    func testNextWorkoutSkipsMissedAndCompleted() {
        XCTAssertEqual(next(on: TestCalendar.date(2026, 11, 4))?.date, TestCalendar.date(2026, 11, 5))

        let first = plan.weeks[0].workouts[0]
        plan.markCompleted(workoutID: first.id, recordID: UUID())
        XCTAssertEqual(next(on: TestCalendar.date(2026, 11, 3))?.date, TestCalendar.date(2026, 11, 5))
    }

    func testNoNextWorkoutAfterThePlanEnds() {
        XCTAssertNil(next(on: TestCalendar.date(2027, 1, 1)))
    }

    func testMarkCompletedSetsRecordID() {
        let workout = plan.weeks[2].workouts[1]
        let recordID = UUID()
        plan.markCompleted(workoutID: workout.id, recordID: recordID)
        XCTAssertEqual(plan.workout(id: workout.id)?.recordID, recordID)
    }

    func testUnknownWorkoutChangesNothing() {
        let before = plan
        plan.markCompleted(workoutID: UUID(), recordID: UUID())
        plan.update(Workout(date: Date(), kind: .easy, title: "Stray", steps: []))
        XCTAssertEqual(plan, before)
    }

    func testUpdateReplacesAndKeepsWeekInDateOrder() {
        var workout = plan.weeks[0].workouts[0]
        workout.date = TestCalendar.date(2026, 11, 6)
        workout.title = "Moved intervals"
        plan.update(workout)

        XCTAssertEqual(plan.weeks[0].workouts.map(\.date), [
            TestCalendar.date(2026, 11, 5), TestCalendar.date(2026, 11, 6), TestCalendar.date(2026, 11, 7),
        ])
        XCTAssertEqual(plan.workout(id: workout.id)?.title, "Moved intervals")
        XCTAssertEqual(plan.workouts.count, 24)
    }
}
