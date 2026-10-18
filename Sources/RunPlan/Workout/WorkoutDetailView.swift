import SwiftUI
import RunCore

/// A planned workout's date and steps, with Start.
struct WorkoutDetailView: View {
    @Environment(AppModel.self) private var app
    let workoutID: UUID

    @State private var choosingMode = false
    @State private var editing = false

    var body: some View {
        if let workout = app.plan?.workout(id: workoutID) {
            detail(workout)
        } else {
            ContentUnavailableView("Workout not found", systemImage: "questionmark.circle")
        }
    }

    private func detail(_ workout: Workout) -> some View {
        List {
            Section {
                LabeledContent("Date", value: workout.date.formatted(date: .complete, time: .omitted))
                if workout.recordID != nil {
                    Label("Completed", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                }
            }
            Section("Steps") {
                ForEach(workout.steps) { step in
                    HStack {
                        Text(label(for: step))
                        Spacer()
                        Text(measure(for: step)).foregroundStyle(.secondary).monospacedDigit()
                    }
                }
            }
        }
        .navigationTitle(workout.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button("Edit") { editing = true }
        }
        .sheet(isPresented: $editing) {
            WorkoutEditView(workout: workout) { app.update($0) }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                choosingMode = true
            } label: {
                Text("Start").font(.title3.bold()).frame(maxWidth: .infinity).padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
        .startRunFlow(isChoosing: $choosingMode) { workout }
    }

    private func label(for step: Step) -> String {
        let kind = CueText.displayKind(step.kind)
        if let count = step.repeatCount, step.repeatGroup != nil {
            return "\(count) × \(kind)"
        }
        return kind
    }

    private func measure(for step: Step) -> String {
        let amount: String
        switch step.measure {
        case .time(let seconds): amount = Pace.clock(seconds)
        case .distance(let meters): amount = String(format: "%.2f mi", Pace.miles(fromMeters: meters))
        case .open: amount = "Until you end it"
        }
        guard let pace = step.targetPaceSecondsPerMile else { return amount }
        return "\(amount) @ \(String(format: "%.1f", Pace.mph(fromSecondsPerMile: pace))) mph"
    }
}
