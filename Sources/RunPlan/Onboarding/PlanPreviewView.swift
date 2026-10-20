import SwiftUI
import RunCore

/// The generated plan before it is saved, with its paces and a warning when the goal time
/// looks out of reach.
struct PlanPreviewView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    let model: OnboardingModel
    /// True when this plan replaces an existing one, which needs a confirmation.
    let isReplacing: Bool

    @State private var confirmingReplace = false

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
                    Text("This goal time needs more improvement than \(model.weeksInRange) weeks usually allow.")
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
                if isReplacing {
                    confirmingReplace = true
                } else {
                    app.createPlan(from: model.profile)
                }
            } label: {
                Text(isReplacing ? "Replace plan" : "Save plan")
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
        .confirmationDialog("Replace your plan?", isPresented: $confirmingReplace, titleVisibility: .visible) {
            Button("Replace plan", role: .destructive) {
                app.createPlan(from: model.profile)
                dismiss()
            }
        } message: {
            Text("The new plan starts fresh. Runs you have already done stay in Runs.")
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
