import SwiftUI
import RunCore

/// Goal, current fitness and schedule, then a preview of the plan before it is saved. Shown on
/// first launch, and from the Plan and Settings tabs to change the current plan.
struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model: OnboardingModel
    /// True when changing an existing plan, rather than on first launch.
    private let isChangingPlan: Bool

    init(changing profile: Profile? = nil) {
        _model = State(initialValue: OnboardingModel(profile: profile))
        isChangingPlan = profile != nil
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(model.page.title)
                .toolbar {
                    if model.page != .goal {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Back") { model.back() }
                        }
                    } else if isChangingPlan {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { dismiss() }
                        }
                    }
                    if model.page != .preview {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Next") { model.next() }.disabled(!model.canContinue)
                        }
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.page {
        case .goal: goalForm
        case .fitness: fitnessForm
        case .schedule: scheduleForm
        case .preview: PlanPreviewView(model: model, isReplacing: isChangingPlan)
        }
    }

    private var goalForm: some View {
        Form {
            Section("Distance") {
                Picker("Distance", selection: $model.distance) {
                    ForEach(RaceDistance.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            Section {
                Toggle("I have a goal time", isOn: $model.hasGoalTime)
                if model.hasGoalTime {
                    DurationPicker(seconds: $model.goalSeconds, minuteRange: OnboardingModel.minuteRange(for: model.distance))
                }
            } footer: {
                Text("Leave this off to train to finish.")
            }
        }
        .onChange(of: model.distance) { _, distance in
            model.goalSeconds = OnboardingModel.defaultSeconds(for: distance)
        }
    }

    private var fitnessForm: some View {
        Form {
            Section {
                Picker("Fitness", selection: $model.fitnessChoice) {
                    ForEach(OnboardingModel.FitnessChoice.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
            if model.fitnessChoice == .recentRace {
                Section("Race result") {
                    Picker("Distance", selection: $model.raceDistance) {
                        ForEach(RaceDistance.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    DurationPicker(seconds: $model.raceSeconds, minuteRange: OnboardingModel.minuteRange(for: model.raceDistance))
                }
            }
        }
        .onChange(of: model.raceDistance) { _, distance in
            model.raceSeconds = OnboardingModel.defaultSeconds(for: distance)
        }
    }

    private var scheduleForm: some View {
        Form {
            Section {
                ForEach(Weekday.allCases, id: \.self) { day in
                    Button {
                        model.toggle(day)
                    } label: {
                        HStack {
                            Text(day.name).foregroundStyle(.primary)
                            Spacer()
                            if model.runDays.contains(day) {
                                Image(systemName: "checkmark").foregroundStyle(.tint)
                            }
                        }
                    }
                    .accessibilityAddTraits(model.runDays.contains(day) ? .isSelected : [])
                }
            } header: {
                Text("Run days")
            } footer: {
                Text("Pick 2 to 5 days. The last one each week is the long run.")
            }
            Section("Plan length") {
                Stepper("\(model.planWeeks) weeks", value: $model.planWeeks, in: Profile.planWeeksRange)
            }
            Section("Start") {
                DatePicker(
                    "Start date",
                    selection: $model.startDate,
                    in: Calendar.current.startOfDay(for: Date())...,
                    displayedComponents: .date
                )
            }
        }
    }
}
