import SwiftUI
import RunCore

/// Workout preferences, changing the plan, and resetting everything.
struct SettingsView: View {
    @Environment(AppModel.self) private var app

    @State private var changingPlan = false
    @State private var confirmingReset = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Keep screen awake", isOn: binding(\.keepScreenAwake))
                    Toggle("Voice cues", isOn: binding(\.voiceCues))
                    Toggle("Auto-pause outdoors", isOn: binding(\.autoPause))
                } header: {
                    Text("During a workout")
                } footer: {
                    Text("Voice cues covers step announcements, mile splits and pace cues; the countdown beeps always play. Auto-pause stops the clock when you stop moving outdoors and starts it again when you set off.")
                }

                Section {
                    Button("Change plan") { changingPlan = true }
                } footer: {
                    Text("Opens your answers so you can change them. The new plan starts fresh, and your runs stay in History.")
                }

                Section {
                    Button("Reset everything", role: .destructive) { confirmingReset = true }
                } footer: {
                    Text("Deletes your plan, every run and these settings, then starts setup again.")
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $changingPlan) {
                OnboardingView(changing: app.plan?.profile)
            }
            .confirmationDialog("Reset everything?", isPresented: $confirmingReset, titleVisibility: .visible) {
                Button("Delete plan, runs and settings", role: .destructive) { app.reset() }
            } message: {
                Text("This cannot be undone.")
            }
        }
    }

    private func binding(_ keyPath: WritableKeyPath<AppSettings, Bool>) -> Binding<Bool> {
        Binding(
            get: { app.settings[keyPath: keyPath] },
            set: { value in app.updateSettings { $0[keyPath: keyPath] = value } }
        )
    }
}
