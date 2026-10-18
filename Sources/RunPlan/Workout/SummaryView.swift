import SwiftUI
import MapKit
// SwiftUI's Map lives in this cross-import overlay; xtool's build does not pull it in on its own.
import _MapKit_SwiftUI
import RunCore

/// One screen, every field skippable. Outdoors the distance is measured and the splits and
/// route are shown; on a treadmill the distance is typed in.
struct SummaryView: View {
    @Environment(AppModel.self) private var app
    let session: WorkoutSessionModel

    @State private var distanceText = ""
    @State private var effort = 0
    @State private var notes = ""

    private var isOutdoor: Bool { session.mode == .outdoor }

    var body: some View {
        NavigationStack {
            Form {
                Section("Workout") {
                    LabeledContent("Time", value: Pace.clock(session.durationSeconds))
                    if isOutdoor {
                        LabeledContent("Distance", value: String(format: "%.2f mi", Pace.miles(fromMeters: distanceMeters)))
                    }
                    if let pace = Pace.secondsPerMile(distanceMeters: distanceMeters, durationSeconds: session.durationSeconds) {
                        LabeledContent("Average pace", value: "\(Pace.clock(pace)) /mi")
                    }
                }

                if isOutdoor {
                    if !session.splits.isEmpty {
                        Section("Splits") {
                            ForEach(session.splits, id: \.index) { split in
                                LabeledContent(splitLabel(split), value: Pace.clock(split.durationSeconds))
                            }
                        }
                    }
                    if session.route.count > 1 {
                        Section("Route") {
                            // Zoom only, so a drag on the map scrolls the form instead of panning.
                            Map(initialPosition: .automatic, interactionModes: [.zoom]) {
                                MapPolyline(coordinates: session.route.map {
                                    CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
                                })
                                .stroke(.orange, lineWidth: 4)
                            }
                            .frame(height: 240)
                            .listRowInsets(EdgeInsets())
                        }
                    }
                } else {
                    Section("Distance (miles, from the treadmill)") {
                        TextField("Optional", text: $distanceText)
                            .keyboardType(.decimalPad)
                    }
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
        if isOutdoor { return session.distanceMeters }
        let normalized = distanceText.replacingOccurrences(of: ",", with: ".")
        guard let miles = Double(normalized), miles > 0 else { return 0 }
        return Pace.meters(fromMiles: miles)
    }

    private func splitLabel(_ split: Split) -> String {
        guard split.distanceMeters < Pace.metersPerMile - 1 else { return "Mile \(split.index)" }
        return String(format: "Last %.2f mi", Pace.miles(fromMeters: split.distanceMeters))
    }

    private var record: RunRecord {
        RunRecord(
            // A free run is never in the plan, so it gets no workout ID.
            workoutID: app.plan?.workout(id: session.workout.id) == nil ? nil : session.workout.id,
            title: session.workout.title,
            mode: session.mode,
            startedAt: session.startedAt,
            durationSeconds: session.durationSeconds,
            distanceMeters: distanceMeters,
            perceivedEffort: effort == 0 ? nil : effort,
            notes: notes,
            splits: session.splits,
            route: session.route
        )
    }
}
