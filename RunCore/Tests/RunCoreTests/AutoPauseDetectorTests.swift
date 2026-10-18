import XCTest
@testable import RunCore

final class AutoPauseDetectorTests: XCTestCase {

    /// 4 m/s until 30 s, standing at 120 m until 60 s, then 3 m/s.
    private func position(at second: Int) -> Double {
        if second <= 30 { return Double(4 * second) }
        if second <= 60 { return 120 }
        return 120 + Double(3 * (second - 60))
    }

    func testPausesWhenStoppedAndResumesWhenMovingAgain() {
        var detector = AutoPauseDetector()
        var running = true
        var actions: [(Int, AutoPauseDetector.Action)] = []

        for second in 0...80 {
            if let action = detector.update(fix(at: Double(second), north: position(at: second)), isRunning: running) {
                actions.append((second, action))
                running = action == .resume
            }
        }

        XCTAssertEqual(actions.map { $0.0 }, [36, 63])
        XCTAssertEqual(actions.map { $0.1 }, [.pause, .resume])
    }

    func testNothingHappensWithTooLittleData() {
        var detector = AutoPauseDetector()
        for second in 0...3 {
            XCTAssertNil(detector.update(fix(at: Double(second), north: 0), isRunning: true))
        }
    }

    func testManualPausesAreNeverResumedAutomatically() {
        var paused = AutoPauseDetector()
        for second in 0...80 {
            XCTAssertNil(paused.update(fix(at: Double(second), north: position(at: second)), isRunning: false))
        }

        var overridden = AutoPauseDetector()
        var actions: [AutoPauseDetector.Action] = []
        for second in 0...80 {
            if second == 40 { overridden.manualOverride() }
            if let action = overridden.update(fix(at: Double(second), north: position(at: second)), isRunning: second <= 36) {
                actions.append(action)
            }
        }
        XCTAssertEqual(actions, [.pause])
        XCTAssertFalse(overridden.isAutoPaused)
    }
}
