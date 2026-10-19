import SwiftUI
import RunCore

/// Saved runs, newest first, each opening its summary.
struct HistoryView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        NavigationStack {
            List {
                if app.records.isEmpty {
                    Text("No runs yet").foregroundStyle(.secondary)
                } else {
                    ForEach(app.records) { record in
                        NavigationLink(value: record.id) {
                            RunRow(record: record)
                        }
                    }
                }
            }
            .navigationTitle("History")
            .navigationDestination(for: UUID.self) { id in
                if let record = app.records.first(where: { $0.id == id }) {
                    RunDetailView(record: record)
                } else {
                    ContentUnavailableView("Run not found", systemImage: "questionmark.circle")
                }
            }
        }
    }
}

private struct RunRow: View {
    let record: RunRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(record.title).font(.headline)
            Text(detail).font(.subheadline).foregroundStyle(.secondary)
        }
    }

    private var detail: String {
        var parts = [record.startedAt.formatted(date: .abbreviated, time: .shortened), Pace.clock(record.durationSeconds)]
        if record.distanceMeters > 0 {
            parts.append(String(format: "%.2f mi", Pace.miles(fromMeters: record.distanceMeters)))
        }
        return parts.joined(separator: " · ")
    }
}
