import XCTest
@testable import RunCore

final class PaceCalculatorTests: XCTestCase {

    func testEquivalentTimeUsesRiegel() {
        XCTAssertEqual(PaceCalculator.equivalentTime(seconds: 1800, from: .fiveK, to: .tenK), 3753)
        XCTAssertEqual(PaceCalculator.equivalentTime(seconds: 1500, from: .fiveK, to: .fiveK), 1500)
    }

    func testPaceOverDistance() {
        XCTAssertEqual(PaceCalculator.pace(seconds: 1500, over: .fiveK), 483)
        XCTAssertEqual(PaceCalculator.pace(seconds: 3000, over: .tenK), 483)
    }

    func testPacesFromFiveKGoal() {
        let paces = PaceCalculator.paces(goal: Goal(distance: .fiveK, targetSeconds: 1500), fitness: .newRunner)
        XCTAssertEqual(paces, TrainingPaces(easy: 573, tempo: 508, interval: 483, goal: 483))
    }

    func testPacesFromTenKGoal() {
        let paces = PaceCalculator.paces(goal: Goal(distance: .tenK, targetSeconds: 3000), fitness: .runsTwentyMinutes)
        XCTAssertEqual(paces, TrainingPaces(easy: 553, tempo: 488, interval: 463, goal: 483))
    }

    func testJustFinishUsesRaceResult() {
        let paces = PaceCalculator.paces(
            goal: Goal(distance: .tenK),
            fitness: .recentRace(distance: .fiveK, seconds: 1800)
        )
        XCTAssertEqual(paces, TrainingPaces(easy: 669, tempo: 604, interval: 579, goal: 604))
    }

    func testJustFinishWithNoRaceUsesDefaults() {
        let paces = PaceCalculator.paces(goal: Goal(distance: .fiveK), fitness: .runsTwentyMinutes)
        XCTAssertEqual(paces, .defaults)
        XCTAssertNil(paces.goal)
    }

    func testGoalCheckFromRaceResult() {
        let race = Fitness.recentRace(distance: .fiveK, seconds: 1800)
        XCTAssertEqual(PaceCalculator.assess(makeProfile(goal: Goal(distance: .fiveK, targetSeconds: 1680), fitness: race)), .reachable)
        XCTAssertEqual(
            PaceCalculator.assess(makeProfile(goal: Goal(distance: .fiveK, targetSeconds: 1560), fitness: race)),
            .ambitious(suggestedWeeks: 14)
        )
    }

    func testGoalCheckFromFitnessLevel() {
        XCTAssertEqual(
            PaceCalculator.assess(makeProfile(goal: Goal(distance: .fiveK, targetSeconds: 1500), fitness: .newRunner, weeks: 16)),
            .ambitious(suggestedWeeks: nil)
        )
        XCTAssertEqual(
            PaceCalculator.assess(makeProfile(goal: Goal(distance: .tenK, targetSeconds: 4200), fitness: .runsTwentyMinutes, weeks: 12)),
            .reachable
        )
        XCTAssertEqual(PaceCalculator.assess(makeProfile(goal: Goal(distance: .fiveK), fitness: .newRunner)), .reachable)
    }

    func testGoalCheckIsExactAtWholePercentBoundaries() {
        let race = Fitness.recentRace(distance: .fiveK, seconds: 1800)
        XCTAssertEqual(
            PaceCalculator.assess(makeProfile(goal: Goal(distance: .fiveK, targetSeconds: 1548), fitness: race, weeks: 8)),
            .ambitious(suggestedWeeks: 14)
        )
        XCTAssertEqual(
            PaceCalculator.assess(makeProfile(goal: Goal(distance: .fiveK, targetSeconds: 1512), fitness: race, weeks: 16)),
            .reachable
        )
        XCTAssertEqual(
            PaceCalculator.assess(makeProfile(goal: Goal(distance: .fiveK, targetSeconds: 1494), fitness: race, weeks: 16)),
            .ambitious(suggestedWeeks: nil)
        )
        XCTAssertEqual(
            PaceCalculator.assess(makeProfile(goal: Goal(distance: .fiveK, targetSeconds: 1980), fitness: race, weeks: 8)),
            .reachable
        )
    }
}
