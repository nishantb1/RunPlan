import Foundation

/// Builds a training plan from onboarding answers. Deterministic: the same profile and
/// calendar always give the same weeks, dates and steps; only the generated IDs differ.
///
/// - Weeks: the last week is a taper ending in a time trial at the goal distance, every fourth
///   other week is a cutback at 75 percent, and the rest are build weeks.
/// - Walk-run: a runner who cannot yet run 20 minutes climbs `WalkRunLevel.ladder` one rung
///   per build week, then switches to running.
/// - Running: the week's easy-run length starts at 20 minutes (30 with a race result) and
///   grows 10 percent per build week, capped by goal distance. Run days in Monday-first order
///   take roles: the first is the quality session (intervals and tempo alternating), the last
///   is the long run at 1.5 times easy length, and any others are easy runs.
public enum PlanGenerator {

    enum DayRole {
        case quality
        case easy
        case long
    }

    struct RunDay {
        let date: Date
        let role: DayRole
    }

    public static func generate(_ profile: Profile, calendar: Calendar = .current) -> Plan {
        guard profile.planWeeks > 0 else { return Plan(profile: profile, weeks: []) }

        let paces = PaceCalculator.paces(goal: profile.goal, fitness: profile.fitness)
        let builder = WorkoutBuilder(paces: paces, goal: profile.goal)
        let start = calendar.startOfDay(for: profile.startDate)

        var walkRunIndex = WalkRunLevel.startIndex(for: profile.fitness)
        var easyMinutes: Int?
        var qualityCount = 0
        var weeks: [Week] = []

        for number in 1...profile.planWeeks {
            let kind = weekKind(number, of: profile.planWeeks)
            let days = runDays(inWeek: number, from: start, profile: profile, calendar: calendar)
            let workouts: [Workout]

            if let index = walkRunIndex {
                let level = WalkRunLevel.ladder[kind == .build ? index : max(index - 1, 0)]
                workouts = days.map { day in
                    guard day.role == .long else {
                        return builder.walkRun(level, extraRep: false, on: day.date)
                    }
                    return kind == .taper
                        ? builder.timeTrial(afterWalkRun: true, on: day.date)
                        : builder.walkRun(level, extraRep: true, on: day.date)
                }
                if kind == .build {
                    walkRunIndex = index + 1 < WalkRunLevel.ladder.count ? index + 1 : nil
                }
            } else {
                let minutes = nextEasyMinutes(after: easyMinutes, kind: kind, profile: profile)
                easyMinutes = minutes

                if kind == .taper {
                    let easy = Scaling.round(minutes, times: 3, over: 5)
                    workouts = days.map { day in
                        day.role == .long
                            ? builder.timeTrial(afterWalkRun: false, on: day.date)
                            : builder.easy(minutes: easy, on: day.date)
                    }
                } else {
                    let level = kind == .build ? minutes : Scaling.round(minutes, times: 3, over: 4)
                    let longMinutes = min(Scaling.round(level, times: 3, over: 2), longRunCap(profile.goal.distance))
                    let intervalsWeek = qualityCount.isMultiple(of: 2)
                    qualityCount += 1
                    workouts = days.map { day in
                        switch day.role {
                        case .quality:
                            return intervalsWeek
                                ? builder.intervals(level: level, on: day.date)
                                : builder.tempo(level: level, on: day.date)
                        case .long:
                            return builder.longRun(minutes: longMinutes, on: day.date)
                        case .easy:
                            return builder.easy(minutes: level, on: day.date)
                        }
                    }
                }
            }

            weeks.append(Week(number: number, kind: kind, workouts: workouts))
        }

        return Plan(profile: profile, weeks: weeks)
    }

    static func weekKind(_ number: Int, of total: Int) -> WeekKind {
        if number == total { return .taper }
        return number.isMultiple(of: 4) ? .cutback : .build
    }

    /// The first running week starts the easy run at 20 minutes, or 30 with a race result.
    /// Build weeks then add 10 percent up to the cap; cutback and taper weeks hold it.
    static func nextEasyMinutes(after current: Int?, kind: WeekKind, profile: Profile) -> Int {
        guard let current else {
            if case .recentRace = profile.fitness { return 30 }
            return 20
        }
        guard kind == .build else { return current }
        return min(current * 11 / 10, easyRunCap(profile.goal.distance))
    }

    static func easyRunCap(_ distance: RaceDistance) -> Int {
        switch distance {
        case .fiveK: return 40
        case .tenK: return 50
        }
    }

    /// A safety bound: with today's easy-run caps (40 and 50 minutes) the long run tops out at 60 and 75 minutes, so this never binds.
    static func longRunCap(_ distance: RaceDistance) -> Int {
        switch distance {
        case .fiveK: return 60
        case .tenK: return 90
        }
    }

    /// The run days inside week `number`'s 7-day window from `start`, in date order.
    static func runDays(inWeek number: Int, from start: Date, profile: Profile, calendar: Calendar) -> [RunDay] {
        let ordered = profile.runDays.sorted()
        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: (number - 1) * 7 + offset, to: start) else {
                return nil
            }
            guard let position = ordered.firstIndex(of: Weekday(of: date, calendar: calendar)) else {
                return nil
            }
            return RunDay(date: date, role: role(at: position, of: ordered.count))
        }
    }

    static func role(at position: Int, of count: Int) -> DayRole {
        if position == count - 1 { return .long }
        if position == 0 { return .quality }
        return .easy
    }
}
