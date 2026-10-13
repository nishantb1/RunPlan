import XCTest
@testable import RunCore

final class StepExpanderTests: XCTestCase {

    func testRepeatGroupExpandsToFlatSequence() {
        let steps = [
            Step(kind: .warmup, measure: .time(seconds: 300)),
            Step(kind: .run, measure: .time(seconds: 90), targetPaceSecondsPerMile: 766, repeatGroup: 1, repeatCount: 3),
            Step(kind: .walk, measure: .time(seconds: 120), repeatGroup: 1, repeatCount: 3),
            Step(kind: .cooldown, measure: .time(seconds: 180)),
        ]

        let flat = StepExpander.expand(steps)

        XCTAssertEqual(flat.map(\.kind), [.warmup, .run, .walk, .run, .walk, .run, .walk, .cooldown])
        XCTAssertEqual(flat[1].durationSeconds, 90)
        XCTAssertEqual(flat[1].targetPaceSecondsPerMile, 766)
        XCTAssertEqual(flat[1].sourceStepID, steps[1].id)
    }

    func testTwoGroupsAndUngroupedSteps() {
        let steps = [
            Step(kind: .run, measure: .time(seconds: 60), repeatGroup: 1, repeatCount: 2),
            Step(kind: .walk, measure: .time(seconds: 30), repeatGroup: 1, repeatCount: 2),
            Step(kind: .run, measure: .time(seconds: 600)),
            Step(kind: .run, measure: .time(seconds: 20), repeatGroup: 2, repeatCount: 2),
            Step(kind: .recovery, measure: .time(seconds: 40), repeatGroup: 2, repeatCount: 2),
        ]

        let flat = StepExpander.expand(steps)

        XCTAssertEqual(flat.map(\.durationSeconds), [60, 30, 60, 30, 600, 20, 40, 20, 40])
    }

    func testDistanceStepHasNoDuration() {
        let flat = StepExpander.expand([Step(kind: .run, measure: .distance(meters: 5000))])

        XCTAssertNil(flat[0].durationSeconds)
        XCTAssertEqual(flat[0].distanceMeters, 5000)
        XCTAssertTrue(flat[0].isOpenEnded)
    }

    func testMissingRepeatCountMeansOnce() {
        let flat = StepExpander.expand([Step(kind: .run, measure: .time(seconds: 60), repeatGroup: 1)])
        XCTAssertEqual(flat.count, 1)
    }
}
