import XCTest
@testable import RunCore

final class CueSchedulerTests: XCTestCase {

    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    private func makeEngine() -> WorkoutEngine {
        let engine = WorkoutEngine(planSteps: [
            Step(kind: .run, measure: .time(seconds: 10)),
            Step(kind: .walk, measure: .time(seconds: 10)),
        ])
        engine.start(now: t0)
        return engine
    }

    private func events(_ scheduler: inout CueScheduler, _ engine: WorkoutEngine, at offset: TimeInterval) throws -> [CueEvent] {
        let snapshot = try XCTUnwrap(engine.snapshot(now: t0.addingTimeInterval(offset)))
        return scheduler.events(for: snapshot)
    }

    func testAnnouncesEachStepOnce() throws {
        let engine = makeEngine()
        var scheduler = CueScheduler()

        XCTAssertEqual(try events(&scheduler, engine, at: 0), [.announce(engine.steps[0])])
        XCTAssertEqual(try events(&scheduler, engine, at: 1), [])
        XCTAssertEqual(try events(&scheduler, engine, at: 10), [.announce(engine.steps[1])])
    }

    func testBeepsOnceAtThreeTwoOne() throws {
        let engine = makeEngine()
        var scheduler = CueScheduler()
        _ = try events(&scheduler, engine, at: 0)

        XCTAssertEqual(try events(&scheduler, engine, at: 6.9), [])
        XCTAssertEqual(try events(&scheduler, engine, at: 7.1), [.countdownBeep])
        XCTAssertEqual(try events(&scheduler, engine, at: 7.4), [])
        XCTAssertEqual(try events(&scheduler, engine, at: 8.2), [.countdownBeep])
        XCTAssertEqual(try events(&scheduler, engine, at: 9.3), [.countdownBeep])
        XCTAssertEqual(try events(&scheduler, engine, at: 9.6), [])
    }

    func testNoBeepWhilePaused() throws {
        let engine = makeEngine()
        var scheduler = CueScheduler()
        _ = try events(&scheduler, engine, at: 0)

        engine.pause(now: t0.addingTimeInterval(7.5))
        XCTAssertEqual(try events(&scheduler, engine, at: 60), [])
    }

    func testReannouncesAfterSkipBack() throws {
        let engine = makeEngine()
        var scheduler = CueScheduler()
        _ = try events(&scheduler, engine, at: 0)
        _ = try events(&scheduler, engine, at: 12)

        engine.skipBack(now: t0.addingTimeInterval(13))
        XCTAssertEqual(try events(&scheduler, engine, at: 13), [.announce(engine.steps[0])])
    }

    func testFinishedFiresOnce() throws {
        let engine = makeEngine()
        var scheduler = CueScheduler()
        _ = try events(&scheduler, engine, at: 0)

        XCTAssertEqual(try events(&scheduler, engine, at: 25), [.finished])
        XCTAssertEqual(try events(&scheduler, engine, at: 26), [])
    }
}
