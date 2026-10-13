import SwiftUI
import RunCore

struct HomeView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        NavigationStack {
            List {
                Section("Today") {
                    NavigationLink {
                        WorkoutDetailView(workout: app.todaysWorkout)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(app.todaysWorkout.title).font(.headline)
                            Text(plannedText(app.todaysWorkout)).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Recent runs") {
                    if app.records.isEmpty {
                        Text("No runs yet").foregroundStyle(.secondary)
                    } else {
                        ForEach(app.records) { record in
                            RunRow(record: record)
                        }
                    }
                }
            }
            .navigationTitle("RunPlan")
        }
    }

    private func plannedText(_ workout: Workout) -> String {
        let planned = WorkoutEngine(planSteps: workout.steps).totalPlanned
        return "\(Pace.clock(Int(planned))) planned"
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
