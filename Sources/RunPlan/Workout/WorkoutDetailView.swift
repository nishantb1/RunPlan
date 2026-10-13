import SwiftUI
import RunCore

struct WorkoutDetailView: View {
    @Environment(AppModel.self) private var app
    let workout: Workout

    @State private var choosingMode = false

    var body: some View {
        List {
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
        .safeAreaInset(edge: .bottom) {
            Button {
                choosingMode = true
            } label: {
                Text("Start").font(.title3.bold()).frame(maxWidth: .infinity).padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
        .confirmationDialog("Where are you running?", isPresented: $choosingMode, titleVisibility: .visible) {
            Button("Treadmill") { app.start(workout, mode: .treadmill) }
            Button("Outdoor (coming with GPS tracking)") {}.disabled(true)
        }
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
        }
        guard let pace = step.targetPaceSecondsPerMile else { return amount }
        return "\(amount) @ \(String(format: "%.1f", Pace.mph(fromSecondsPerMile: pace))) mph"
    }
}
