import XCTest
@testable import RunCore

final class WorkoutRepeatGroupTests: XCTestCase {

    // warm-up, 6 × (run, walk), cool-down
    private var workout = SampleWorkouts.runWalk(on: TestCalendar.date(2026, 11, 3))

    func testGroupStart() {
        XCTAssertFalse(workout.startsRepeatGroup(at: 0))
        XCTAssertTrue(workout.startsRepeatGroup(at: 1))
        XCTAssertFalse(workout.startsRepeatGroup(at: 2))
        XCTAssertFalse(workout.startsRepeatGroup(at: 9))
    }

    func testRepeatCountReadsTheGroup() {
        XCTAssertEqual(workout.repeatCount(ofGroupAt: 2), 6)
        XCTAssertEqual(workout.repeatCount(ofGroupAt: 0), 1)
        XCTAssertEqual(workout.repeatCount(ofGroupAt: 9), 1)
    }

    func testSetRepeatCountChangesEveryStepInTheGroup() {
        workout.setRepeatCount(8, ofGroupAt: 2)
        XCTAssertEqual(workout.steps.map(\.repeatCount), [nil, 8, 8, nil])
        XCTAssertEqual(StepExpander.expand(workout.steps).count, 18)

        workout.setRepeatCount(3, ofGroupAt: 0)
        XCTAssertNil(workout.steps[0].repeatCount)
    }
}
