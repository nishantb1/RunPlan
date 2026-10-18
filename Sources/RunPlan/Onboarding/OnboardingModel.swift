import Foundation
import Observation
import RunCore

/// Draft onboarding answers, turned into a `Profile` for the preview and the saved plan.
@MainActor
@Observable
final class OnboardingModel {

    enum Page: Int, CaseIterable {
        case goal
        case fitness
        case schedule
        case preview

        var title: String {
            switch self {
            case .goal: return "Your goal"
            case .fitness: return "Your running now"
            case .schedule: return "Your schedule"
            case .preview: return "Your plan"
            }
        }
    }

    enum FitnessChoice: String, CaseIterable, Identifiable {
        case newRunner
        case runsFiveMinutes
        case runsTwentyMinutes
        case recentRace

        var id: String { rawValue }

        var title: String {
            switch self {
            case .newRunner: return "New to running"
            case .runsFiveMinutes: return "Can run 5 minutes"
            case .runsTwentyMinutes: return "Can run 20 minutes"
            case .recentRace: return "I have a recent race time"
            }
        }
    }

    var page: Page = .goal

    var distance: RaceDistance = .fiveK
    var hasGoalTime = false
    /// Starts at 30:00; the view resets it when the distance changes.
    var goalSeconds = 1800

    var fitnessChoice: FitnessChoice = .runsTwentyMinutes
    var raceDistance: RaceDistance = .fiveK
    var raceSeconds = 1800

    var runDays: Set<Weekday> = [.tuesday, .thursday, .saturday]
    var planWeeks = 8
    var startDate = Calendar.current.startOfDay(for: Date())

    var profile: Profile {
        Profile(
            goal: Goal(distance: distance, targetSeconds: hasGoalTime ? goalSeconds : nil),
            fitness: fitness,
            runDays: Array(runDays),
            planWeeks: planWeeks,
            startDate: startDate
        )
    }

    var canContinue: Bool {
        page != .schedule || Profile.daysPerWeekRange.contains(runDays.count)
    }

    func next() {
        if let nextPage = Page(rawValue: page.rawValue + 1) { page = nextPage }
    }

    func back() {
        if let previousPage = Page(rawValue: page.rawValue - 1) { page = previousPage }
    }

    func toggle(_ day: Weekday) {
        if runDays.contains(day) {
            runDays.remove(day)
        } else {
            runDays.insert(day)
        }
    }

    private var fitness: Fitness {
        switch fitnessChoice {
        case .newRunner: return .newRunner
        case .runsFiveMinutes: return .runsFiveMinutes
        case .runsTwentyMinutes: return .runsTwentyMinutes
        case .recentRace: return .recentRace(distance: raceDistance, seconds: raceSeconds)
        }
    }

    /// A typical time to start the wheels on: 30:00 for 5K, 60:00 for 10K.
    nonisolated static func defaultSeconds(for distance: RaceDistance) -> Int {
        switch distance {
        case .fiveK: return 1800
        case .tenK: return 3600
        }
    }

    /// Minutes offered on the wheel for a time at `distance`.
    nonisolated static func minuteRange(for distance: RaceDistance) -> ClosedRange<Int> {
        switch distance {
        case .fiveK: return 12...60
        case .tenK: return 25...120
        }
    }
}
