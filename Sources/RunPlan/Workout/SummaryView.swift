import SwiftUI
import RunCore

/// One screen, every field skippable. Outdoors the distance is measured and the splits and
/// route are shown; on a treadmill the distance is typed in.
struct SummaryView: View {
    @Environment(AppModel.self) private var app
    let session: WorkoutSessionModel

    @State private var distanceText = ""
    @State private var effort = 0
    @State private var feeling: Feeling?
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
                                LabeledContent(SplitLabel.text(for: split), value: Pace.clock(split.durationSeconds))
                            }
                        }
                    }
                    if session.route.hasLine {
                        Section("Route") {
                            RouteMap(route: session.route)
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

                Section {
                    Picker("How did that feel?", selection: $feeling) {
                        Text("Skip").tag(Feeling?.none)
                        ForEach(Feeling.allCases, id: \.self) { feeling in
                            Text(feeling.displayName).tag(Feeling?.some(feeling))
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("How did that feel?")
                } footer: {
                    if isLadderWorkout {
                        Text("Too hard repeats this step next week instead of moving up. Repeating a step is normal.")
                    }
                }

                Section("Notes") {
                    TextField("Optional", text: $notes, axis: .vertical)
                }
            }
            .navigationTitle("Summary")
            .onAppear {
                // Not finishing a beginner session is the usual sign to repeat it.
                if session.endedEarly, isLadderWorkout { feeling = .tooHard }
            }
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

    /// Whether the workout is part of a beginner plan, where Too hard holds the step.
    private var isLadderWorkout: Bool {
        app.plan?.weeks.contains { week in
            week.ladderStep != nil && week.workouts.contains { $0.id == session.workout.id }
        } ?? false
    }

    private var distanceMeters: Double {
        if isOutdoor { return session.distanceMeters }
        let normalized = distanceText.replacingOccurrences(of: ",", with: ".")
        guard let miles = Double(normalized), miles > 0 else { return 0 }
        return Pace.meters(fromMiles: miles)
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
            feeling: feeling,
            runSeconds: session.runSeconds,
            runMeters: session.runMeters,
            notes: notes,
            splits: session.splits,
            route: session.route
        )
    }
}
