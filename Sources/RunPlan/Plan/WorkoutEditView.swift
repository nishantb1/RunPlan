import SwiftUI
import RunCore

/// Edits a copy of a planned workout: title, date and steps. Nothing changes until Save.
struct WorkoutEditView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Workout
    let onSave: (Workout) -> Void

    init(workout: Workout, onSave: @escaping (Workout) -> Void) {
        _draft = State(initialValue: workout)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $draft.title)
                    DatePicker("Date", selection: $draft.date, displayedComponents: .date)
                }
                Section {
                    ForEach($draft.steps) { $step in
                        let index = draft.steps.firstIndex { $0.id == step.id } ?? 0
                        StepEditor(
                            step: $step,
                            repeatCount: draft.startsRepeatGroup(at: index) ? repeatCount(forStep: step.id) : nil
                        )
                    }
                    .onDelete { draft.steps.remove(atOffsets: $0) }
                    Button("Add step") {
                        draft.steps.append(Step(kind: .run, measure: .time(seconds: 300)))
                    }
                } header: {
                    Text("Steps")
                } footer: {
                    Text("Swipe a step to delete it.")
                }
            }
            .navigationTitle("Edit workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(draft)
                        dismiss()
                    }
                    .disabled(draft.steps.isEmpty || draft.title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    /// The repeat count of the group starting at the step with `id`, looked up on every access
    /// because deleting steps shifts indices.
    private func repeatCount(forStep id: UUID) -> Binding<Int> {
        Binding(
            get: {
                guard let index = draft.steps.firstIndex(where: { $0.id == id }) else { return 1 }
                return draft.repeatCount(ofGroupAt: index)
            },
            set: { count in
                guard let index = draft.steps.firstIndex(where: { $0.id == id }) else { return }
                draft.setRepeatCount(count, ofGroupAt: index)
            }
        )
    }
}
