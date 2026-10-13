import XCTest
@testable import RunCore

final class StepResolverTests: XCTestCase {

    private let steps = StepExpander.expand([
        Step(kind: .warmup, measure: .time(seconds: 300)),
        Step(kind: .run, measure: .time(seconds: 90)),
        Step(kind: .walk, measure: .time(seconds: 120)),
    ])

    func testEmptyStepsResolveToNil() {
        XCTAssertNil(StepResolver.resolve(steps: [], elapsed: 10))
    }

    func testMidStep() throws {
        let r = try XCTUnwrap(StepResolver.resolve(steps: steps, elapsed: 310))
        XCTAssertEqual(r.index, 1)
        XCTAssertEqual(r.elapsedInStep, 10)
        XCTAssertEqual(r.remainingInStep, 80)
        XCTAssertFalse(r.isPastEnd)
    }

    func testExactBoundaryBelongsToNextStep() throws {
        let r = try XCTUnwrap(StepResolver.resolve(steps: steps, elapsed: 300))
        XCTAssertEqual(r.index, 1)
        XCTAssertEqual(r.elapsedInStep, 0)
    }

    func testPastEnd() throws {
        let r = try XCTUnwrap(StepResolver.resolve(steps: steps, elapsed: 9999))
        XCTAssertEqual(r.index, 2)
        XCTAssertTrue(r.isPastEnd)
        XCTAssertEqual(r.remainingInStep, 0)
    }

    func testStopsAtOpenEndedStep() throws {
        let withDistance = StepExpander.expand([
            Step(kind: .warmup, measure: .time(seconds: 300)),
            Step(kind: .run, measure: .distance(meters: 5000)),
            Step(kind: .cooldown, measure: .time(seconds: 300)),
        ])
        let r = try XCTUnwrap(StepResolver.resolve(steps: withDistance, elapsed: 5000))
        XCTAssertEqual(r.index, 1)
        XCTAssertTrue(r.isOpenEnded)
        XCTAssertNil(r.remainingInStep)
        XCTAssertEqual(r.elapsedInStep, 4700)
    }
}
