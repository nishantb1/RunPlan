import SwiftUI
import RunCore

/// One saved run: its summary, splits and notes, and the route map, loaded when opened.
struct RunDetailView: View {
    @Environment(AppModel.self) private var app
    let record: RunRecord

    @State private var route: [RoutePoint] = []

    var body: some View {
        Form {
            Section {
                LabeledContent("Date", value: record.startedAt.formatted(date: .complete, time: .shortened))
                LabeledContent("Where", value: record.mode == .outdoor ? "Outdoor" : "Treadmill")
                LabeledContent("Time", value: Pace.clock(record.durationSeconds))
                if record.distanceMeters > 0 {
                    LabeledContent("Distance", value: String(format: "%.2f mi", Pace.miles(fromMeters: record.distanceMeters)))
                }
                if let pace = Pace.secondsPerMile(distanceMeters: record.distanceMeters, durationSeconds: record.durationSeconds) {
                    LabeledContent("Average pace", value: "\(Pace.clock(pace)) /mi")
                }
                if let effort = record.perceivedEffort {
                    LabeledContent("Effort", value: "\(effort) of 5")
                }
            }

            if !record.splits.isEmpty {
                Section("Splits") {
                    ForEach(record.splits, id: \.index) { split in
                        LabeledContent(SplitLabel.text(for: split), value: Pace.clock(split.durationSeconds))
                    }
                }
            }

            if route.count > 1 {
                Section("Route") {
                    RouteMap(route: route)
                        .frame(height: 240)
                        .listRowInsets(EdgeInsets())
                }
            }

            if !record.notes.isEmpty {
                Section("Notes") {
                    Text(record.notes)
                }
            }
        }
        .navigationTitle(record.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            route = app.route(for: record)
        }
    }
}
