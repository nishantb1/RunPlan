import XCTest
@testable import RunCore

final class FreeRunTests: XCTestCase {

    func testFreeRunIsOneOpenRunStep() {
        let workout = FreeRun.workout(on: trackStart)
        XCTAssertEqual(workout.title, "Free run")
        XCTAssertEqual(workout.steps.map(\.measure), [.open])
        let flat = StepExpander.expand(workout.steps)
        XCTAssertEqual(flat.count, 1)
        XCTAssertTrue(flat[0].isOpenEnded)
        XCTAssertNil(flat[0].distanceMeters)
        XCTAssertEqual(CueText.announcement(for: flat[0], mode: .outdoor), "Run.")
    }

    func testOpenStepRunsUntilEnded() throws {
        let engine = WorkoutEngine(planSteps: FreeRun.workout(on: trackStart).steps)
        engine.start(now: trackStart)
        let snapshot = try XCTUnwrap(engine.snapshot(now: trackStart.addingTimeInterval(7200)))
        XCTAssertEqual(snapshot.state, .running)
        XCTAssertNil(snapshot.remainingInStep)
        XCTAssertEqual(snapshot.totalElapsed, 7200)
        XCTAssertEqual(snapshot.totalPlanned, 0)

        engine.advanceToNextStep(now: trackStart.addingTimeInterval(7201))
        XCTAssertEqual(engine.state, .finished)
    }

    func testOpenMeasureRoundTrips() throws {
        let step = Step(kind: .run, measure: .open)
        XCTAssertEqual(try JSONDecoder().decode(Step.self, from: JSONEncoder().encode(step)), step)
    }
}
