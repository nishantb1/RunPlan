import XCTest
@testable import RunCore

final class CueTextTests: XCTestCase {

    private func flat(_ kind: StepKind, seconds: Int? = nil, meters: Double? = nil, pace: Int? = nil) -> FlatStep {
        FlatStep(sourceStepID: UUID(), kind: kind, durationSeconds: seconds, distanceMeters: meters, targetPaceSecondsPerMile: pace)
    }

    func testTreadmillAnnouncementUsesMph() {
        XCTAssertEqual(
            CueText.announcement(for: flat(.run, seconds: 90, pace: 766), mode: .treadmill),
            "Run, 4.7 miles per hour, 1 minute 30 seconds."
        )
    }

    func testOutdoorAnnouncementUsesPace() {
        XCTAssertEqual(
            CueText.announcement(for: flat(.run, seconds: 120, pace: 600), mode: .outdoor),
            "Run, 10 minutes per mile, 2 minutes."
        )
        XCTAssertEqual(
            CueText.announcement(for: flat(.run, seconds: 45, pace: 766), mode: .outdoor),
            "Run, 12 minutes 46 seconds per mile, 45 seconds."
        )
    }

    func testDistanceStepWithoutTarget() {
        XCTAssertEqual(
            CueText.announcement(for: flat(.run, meters: 5000), mode: .treadmill),
            "Run, 3.1 miles."
        )
    }

    func testTargetLabel() {
        XCTAssertEqual(CueText.target(for: flat(.run, seconds: 90, pace: 766), mode: .treadmill), "4.7 mph")
        XCTAssertEqual(CueText.target(for: flat(.run, seconds: 90, pace: 766), mode: .outdoor), "12:46 /mi")
        XCTAssertNil(CueText.target(for: flat(.walk, seconds: 90), mode: .treadmill))
    }
}
