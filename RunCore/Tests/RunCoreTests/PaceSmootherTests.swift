import XCTest
@testable import RunCore

final class PaceSmootherTests: XCTestCase {

    private func feed(_ smoother: inout PaceSmoother, seconds: ClosedRange<Int>, meters: (Int) -> Double) {
        for second in seconds {
            smoother.add(time: trackStart.addingTimeInterval(Double(second)), totalMeters: meters(second))
        }
    }

    func testPaceOverTheLastFifteenSeconds() {
        var smoother = PaceSmoother()
        feed(&smoother, seconds: 0...20) { Double(3 * $0) }
        XCTAssertEqual(smoother.secondsPerMile, 536)

        var changing = PaceSmoother()
        feed(&changing, seconds: 0...20) { Double(2 * $0) }
        feed(&changing, seconds: 21...40) { 40 + Double(4 * ($0 - 20)) }
        XCTAssertEqual(changing.secondsPerMile, 402)
    }

    func testNoPaceWithoutEnoughData() {
        var standing = PaceSmoother()
        feed(&standing, seconds: 0...20) { _ in 100 }
        XCTAssertNil(standing.secondsPerMile)

        var brief = PaceSmoother()
        feed(&brief, seconds: 0...3) { Double(3 * $0) }
        XCTAssertNil(brief.secondsPerMile)
    }

    func testResetClearsTheWindow() {
        var smoother = PaceSmoother()
        feed(&smoother, seconds: 0...20) { Double(3 * $0) }
        smoother.reset()
        XCTAssertNil(smoother.secondsPerMile)
    }
}
