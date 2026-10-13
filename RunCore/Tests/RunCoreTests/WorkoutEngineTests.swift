import XCTest
@testable import RunCore

final class WorkoutEngineTests: XCTestCase {

    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    private func makeEngine() -> WorkoutEngine {
        WorkoutEngine(planSteps: [
            Step(kind: .warmup, measure: .time(seconds: 300)),
            Step(kind: .run, measure: .time(seconds: 90), repeatGroup: 1, repeatCount: 2),
            Step(kind: .walk, measure: .time(seconds: 120), repeatGroup: 1, repeatCount: 2),
            Step(kind: .cooldown, measure: .time(seconds: 180)),
        ])
    }

    func testNoSnapshotBeforeStart() {
        XCTAssertNil(makeEngine().snapshot(now: t0))
    }

    func testAdvancesByWallClock() throws {
        let engine = makeEngine()
        engine.start(now: t0)

        let s = try XCTUnwrap(engine.snapshot(now: t0.addingTimeInterval(310)))
        XCTAssertEqual(s.stepIndex, 1)
        XCTAssertEqual(s.step.kind, .run)
        XCTAssertEqual(s.remainingInStep, 80)
        XCTAssertEqual(s.totalElapsed, 310)
        XCTAssertEqual(s.totalPlanned, 900)
        XCTAssertEqual(s.stepCount, 6)
        XCTAssertEqual(s.nextStep?.kind, .walk)
    }

    func testLongBackgroundGapLandsOnTheRightStep() throws {
        let engine = makeEngine()
        engine.start(now: t0)

        // 300 + 90 + 120 + 90 = 600, so 650 s is 50 s into the second walk.
        let s = try XCTUnwrap(engine.snapshot(now: t0.addingTimeInterval(650)))
        XCTAssertEqual(s.stepIndex, 4)
        XCTAssertEqual(s.elapsedInStep, 50)
    }

    func testFinishesAfterLastStep() throws {
        let engine = makeEngine()
        engine.start(now: t0)

        let s = try XCTUnwrap(engine.snapshot(now: t0.addingTimeInterval(901)))
        XCTAssertEqual(s.state, .finished)
        XCTAssertEqual(engine.state, .finished)
    }

    func testPauseExcludesPausedTime() throws {
        let engine = makeEngine()
        engine.start(now: t0)
        engine.pause(now: t0.addingTimeInterval(100))
        engine.resume(now: t0.addingTimeInterval(400))

        let s = try XCTUnwrap(engine.snapshot(now: t0.addingTimeInterval(450)))
        XCTAssertEqual(s.totalElapsed, 150)
        XCTAssertEqual(s.stepIndex, 0)
    }

    func testSkipForwardOnLastStepFinishes() {
        let engine = makeEngine()
        engine.start(now: t0)
        for _ in 0..<6 {
            engine.skipForward(now: t0.addingTimeInterval(1))
        }
        XCTAssertEqual(engine.state, .finished)
    }

    func testSkipBackOnFirstStepRestartsIt() throws {
        let engine = makeEngine()
        engine.start(now: t0)
        engine.skipBack(now: t0.addingTimeInterval(100))

        let s = try XCTUnwrap(engine.snapshot(now: t0.addingTimeInterval(110)))
        XCTAssertEqual(s.stepIndex, 0)
        XCTAssertEqual(s.elapsedInStep, 10)
    }

    func testSkipBackGoesToPreviousStep() throws {
        let engine = makeEngine()
        engine.start(now: t0)
        engine.skipBack(now: t0.addingTimeInterval(310))

        let s = try XCTUnwrap(engine.snapshot(now: t0.addingTimeInterval(310)))
        XCTAssertEqual(s.stepIndex, 0)
        XCTAssertEqual(s.elapsedInStep, 0)
    }

    func testDistanceStepWaitsForManualAdvance() throws {
        let engine = WorkoutEngine(planSteps: [
            Step(kind: .warmup, measure: .time(seconds: 60)),
            Step(kind: .run, measure: .distance(meters: 5000)),
            Step(kind: .cooldown, measure: .time(seconds: 60)),
        ])
        engine.start(now: t0)

        let waiting = try XCTUnwrap(engine.snapshot(now: t0.addingTimeInterval(2000)))
        XCTAssertEqual(waiting.stepIndex, 1)
        XCTAssertNil(waiting.remainingInStep)

        engine.advanceToNextStep(now: t0.addingTimeInterval(2000))
        let after = try XCTUnwrap(engine.snapshot(now: t0.addingTimeInterval(2010)))
        XCTAssertEqual(after.stepIndex, 2)
        XCTAssertEqual(after.remainingInStep, 50)
        XCTAssertEqual(after.totalElapsed, 2010)
    }

    func testRestoredRunningCheckpointComesBackPausedAtSaveTime() throws {
        let engine = makeEngine()
        engine.start(now: t0)
        let saved = engine.checkpoint(now: t0.addingTimeInterval(320))

        // The app was killed and relaunched an hour later.
        let restored = WorkoutEngine(steps: engine.steps, restoring: saved)
        XCTAssertEqual(restored.state, .paused)

        let relaunch = t0.addingTimeInterval(3920)
        let paused = try XCTUnwrap(restored.snapshot(now: relaunch))
        XCTAssertEqual(paused.stepIndex, 1)
        XCTAssertEqual(paused.elapsedInStep, 20)

        restored.resume(now: relaunch)
        let resumed = try XCTUnwrap(restored.snapshot(now: relaunch.addingTimeInterval(10)))
        XCTAssertEqual(resumed.stepIndex, 1)
        XCTAssertEqual(resumed.elapsedInStep, 30)
    }

    func testCheckpointRoundTripsThroughJSON() throws {
        let engine = makeEngine()
        engine.start(now: t0)
        let saved = engine.checkpoint(now: t0.addingTimeInterval(5))

        let data = try JSONEncoder().encode(saved)
        XCTAssertEqual(try JSONDecoder().decode(WorkoutEngine.Checkpoint.self, from: data), saved)
    }
}
