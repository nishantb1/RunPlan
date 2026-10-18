import SwiftUI
import RunCore

/// The generated plan before it is saved, with its paces and a warning when the goal time
/// looks out of reach.
struct PlanPreviewView: View {
    @Environment(AppModel.self) private var app
    let model: OnboardingModel

    var body: some View {
        let profile = model.profile
        let plan = PlanGenerator.generate(profile)
        let paces = PaceCalculator.paces(goal: profile.goal, fitness: profile.fitness)

        List {
            switch PaceCalculator.assess(profile) {
            case .reachable:
                EmptyView()
            case .ambitious(let suggestedWeeks):
                Section {
                    Text("This goal time needs more improvement than \(model.planWeeks) weeks usually allow.")
                    if let weeks = suggestedWeeks {
                        Button("Use a \(weeks)-week plan") { model.planWeeks = weeks }
                    }
                    Button("Train to finish instead") { model.hasGoalTime = false }
                } header: {
                    Label("Ambitious goal", systemImage: "exclamationmark.triangle")
                }
            }

            Section("Paces") {
                PaceRow(label: "Easy", seconds: paces.easy)
                PaceRow(label: "Tempo", seconds: paces.tempo)
                PaceRow(label: "Intervals", seconds: paces.interval)
                if let goal = paces.goal {
                    PaceRow(label: "Goal", seconds: goal)
                }
            }

            ForEach(plan.weeks) { week in
                Section("Week \(week.number) · \(week.kind.displayName)") {
                    ForEach(week.workouts) { workout in
                        HStack {
                            Text(workout.title)
                            Spacer()
                            Text(workout.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                app.createPlan(from: model.profile)
            } label: {
                Text("Save plan").font(.title3.bold()).frame(maxWidth: .infinity).padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
    }
}

private struct PaceRow: View {
    let label: String
    let seconds: Int

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text("\(Pace.clock(seconds)) /mi · \(String(format: "%.1f", Pace.mph(fromSecondsPerMile: seconds))) mph")
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}
