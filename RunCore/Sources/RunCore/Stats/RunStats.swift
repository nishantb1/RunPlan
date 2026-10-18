import Foundation

/// Figures for the Progress screen, computed from saved runs.
public enum RunStats {

    /// Runs shorter than this (ended straight away, say, with a little GPS drift) give a
    /// meaningless pace, so the pace trend leaves them out.
    static let minimumPaceMeters = 100.0

    /// Distance and run count for each of the last `weeks` Monday-start weeks up to the week
    /// containing `now`, oldest first. Weeks without runs are included.
    public static func weeklyTotals(_ records: [RunRecord], weeks: Int, endingOn now: Date, calendar: Calendar) -> [WeeklyTotal] {
        var mondayFirst = calendar
        mondayFirst.firstWeekday = 2
        guard weeks > 0, let current = mondayFirst.dateInterval(of: .weekOfYear, for: now) else { return [] }
        return (0..<weeks).reversed().compactMap { weeksBack in
            guard let start = mondayFirst.date(byAdding: .day, value: -7 * weeksBack, to: current.start),
                  let end = mondayFirst.date(byAdding: .day, value: 7, to: start) else { return nil }
            let inWeek = records.filter { $0.startedAt >= start && $0.startedAt < end }
            return WeeklyTotal(weekStart: start, meters: inWeek.reduce(0) { $0 + $1.distanceMeters }, runs: inWeek.count)
        }
    }

    /// Average pace of each run of at least 100 m, oldest first, keeping the last `limit`.
    public static func paceTrend(_ records: [RunRecord], limit: Int) -> [PacePoint] {
        let points = records
            .filter { $0.distanceMeters >= minimumPaceMeters }
            .sorted { $0.startedAt < $1.startedAt }
            .compactMap { record in
                Pace.secondsPerMile(distanceMeters: record.distanceMeters, durationSeconds: record.durationSeconds)
                    .map { PacePoint(date: record.startedAt, secondsPerMile: $0) }
            }
        return Array(points.suffix(max(limit, 0)))
    }

    /// The run with the greatest distance, or nil when no run has a distance.
    public static func longestRun(_ records: [RunRecord]) -> RunRecord? {
        records.filter { $0.distanceMeters > 0 }.max { $0.distanceMeters < $1.distanceMeters }
    }
}
