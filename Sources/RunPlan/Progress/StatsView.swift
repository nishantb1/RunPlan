import SwiftUI
import Charts
import RunCore

/// Plan completion, longest run, weekly distance and average pace.
struct StatsView: View {
    @Environment(AppModel.self) private var app

    @State private var selectedWeek: Date?
    @State private var selectedPaceDate: Date?

    /// Weeks start on Monday, as in `RunStats`, whatever the locale's first weekday, so the bars,
    /// their labels and the selection all line up with the totals.
    private static let weekCalendar: Calendar = {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        return calendar
    }()

    var body: some View {
        let weeks = RunStats.weeklyTotals(app.records, weeks: 8, endingOn: Date(), calendar: Self.weekCalendar)
        let paces = RunStats.paceTrend(app.records, limit: 12)
        let longest = RunStats.longestRun(app.records)

        NavigationStack {
            List {
                if app.plan != nil || longest != nil {
                    Section {
                        HStack(spacing: 12) {
                            if let plan = app.plan {
                                let progress = PlanProgress(plan: plan)
                                StatTile(title: "Plan", value: "\(progress.completed) of \(progress.total)", detail: "workouts done")
                            }
                            if let longest {
                                StatTile(
                                    title: "Longest run",
                                    value: String(format: "%.2f mi", Pace.miles(fromMeters: longest.distanceMeters)),
                                    detail: longest.startedAt.formatted(date: .abbreviated, time: .omitted)
                                )
                            }
                        }
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    }
                }

                Section("Weekly distance") {
                    if weeks.allSatisfy({ $0.runs == 0 }) {
                        Text("No runs in the last 8 weeks.")
                            .foregroundStyle(.secondary)
                    } else {
                        weeklyChart(weeks)
                    }
                }

                Section("Average pace") {
                    if paces.count < 2 {
                        Text("Pace appears after two runs of at least 100 m.")
                            .foregroundStyle(.secondary)
                    } else {
                        paceChart(paces)
                    }
                }
            }
            .navigationTitle("Progress")
        }
    }

    private func weeklyChart(_ weeks: [WeeklyTotal]) -> some View {
        Chart(weeks, id: \.weekStart) { week in
            BarMark(
                x: .value("Week", week.weekStart, unit: .weekOfYear),
                y: .value("Miles", Pace.miles(fromMeters: week.meters)),
                width: .ratio(0.6)
            )
            .foregroundStyle(Color.chartAccent)
            .cornerRadius(4)
            .accessibilityLabel("Week of \(week.weekStart.formatted(.dateTime.month().day()))")
            .accessibilityValue("\(String(format: "%.1f", Pace.miles(fromMeters: week.meters))) miles, \(week.runs) \(week.runs == 1 ? "run" : "runs")")

            if let selectedWeek, Self.weekCalendar.isDate(selectedWeek, equalTo: week.weekStart, toGranularity: .weekOfYear) {
                RuleMark(x: .value("Week", week.weekStart, unit: .weekOfYear))
                    .foregroundStyle(Color.secondary.opacity(0.3))
                    .annotation(position: .top, overflowResolution: .init(x: .fit, y: .disabled)) {
                        Text("\(String(format: "%.1f", Pace.miles(fromMeters: week.meters))) mi · \(week.runs) \(week.runs == 1 ? "run" : "runs")")
                            .font(.caption)
                            .padding(4)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 4))
                    }
            }
        }
        .chartXSelection(value: $selectedWeek)
        .environment(\.calendar, Self.weekCalendar)
        .chartXAxis {
            AxisMarks(values: .stride(by: .weekOfYear, count: 2)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.day().month(.abbreviated))
            }
        }
        .chartYAxisLabel("miles")
        .frame(height: 200)
        .padding(.vertical, 8)
    }

    private func paceChart(_ points: [PacePoint]) -> some View {
        let selected = selectedPaceDate.flatMap { date in
            points.min { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }
        }
        return Chart {
            ForEach(points, id: \.date) { point in
                LineMark(x: .value("Date", point.date), y: .value("Pace", point.secondsPerMile))
                    .foregroundStyle(Color.chartAccent)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    // The points carry each run for VoiceOver, so the line is not read twice.
                    .accessibilityHidden(true)
                PointMark(x: .value("Date", point.date), y: .value("Pace", point.secondsPerMile))
                    .foregroundStyle(Color.chartAccent)
                    .symbolSize(64)
                    .accessibilityLabel(point.date.formatted(date: .abbreviated, time: .omitted))
                    .accessibilityValue("\(Pace.clock(point.secondsPerMile)) per mile")
            }
            if let selected {
                RuleMark(x: .value("Date", selected.date))
                    .foregroundStyle(Color.secondary.opacity(0.3))
                    .annotation(position: .top, overflowResolution: .init(x: .fit, y: .disabled)) {
                        Text("\(Pace.clock(selected.secondsPerMile)) /mi · \(selected.date.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .padding(4)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 4))
                    }
            }
        }
        .chartXSelection(value: $selectedPaceDate)
        // Faster (fewer seconds per mile) is plotted higher.
        .chartYScale(domain: .automatic(includesZero: false, reversed: true))
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel {
                    if let seconds = value.as(Double.self) {
                        Text(Pace.clock(Int(seconds)))
                    }
                }
            }
        }
        .chartYAxisLabel("min/mi, faster is higher")
        .frame(height: 200)
        .padding(.vertical, 8)
    }
}

private struct StatTile: View {
    let title: String
    let value: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            Text(value).font(.title2.bold()).monospacedDigit()
            Text(detail).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}
