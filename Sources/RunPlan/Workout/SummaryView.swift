import SwiftUI
import RunCore

/// One screen, every field skippable.
struct SummaryView: View {
    @Environment(AppModel.self) private var app
    let session: WorkoutSessionModel

    @State private var distanceText = ""
    @State private var effort = 0
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Workout") {
                    LabeledContent("Time", value: Pace.clock(session.durationSeconds))
                    if let pace = Pace.secondsPerMile(distanceMeters: distanceMeters, durationSeconds: session.durationSeconds) {
                        LabeledContent("Average pace", value: "\(Pace.clock(pace)) /mi")
                    }
                }

                Section("Distance (miles, from the treadmill)") {
                    TextField("Optional", text: $distanceText)
                        .keyboardType(.decimalPad)
                }

                Section("Effort") {
                    Picker("Effort", selection: $effort) {
                        Text("Skip").tag(0)
                        ForEach(1...5, id: \.self) { value in
                            Text("\(value)").tag(value)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Notes") {
                    TextField("Optional", text: $notes, axis: .vertical)
                }
            }
            .navigationTitle("Summary")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Discard", role: .destructive) { app.closeSession() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { app.save(record) }
                }
            }
        }
    }

    private var distanceMeters: Double {
        let normalized = distanceText.replacingOccurrences(of: ",", with: ".")
        guard let miles = Double(normalized), miles > 0 else { return 0 }
        return Pace.meters(fromMiles: miles)
    }

    private var record: RunRecord {
        RunRecord(
            workoutID: session.workout.id,
            title: session.workout.title,
            mode: session.mode,
            startedAt: session.startedAt,
            durationSeconds: session.durationSeconds,
            distanceMeters: distanceMeters,
            perceivedEffort: effort == 0 ? nil : effort,
            notes: notes
        )
    }
}
