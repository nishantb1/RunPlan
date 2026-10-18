import SwiftUI
import RunCore

/// Before an outdoor run: asks for location permission, then waits for a usable GPS fix. If
/// location is off, explains why and offers treadmill mode instead.
struct OutdoorStartView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    /// Called with the chosen mode just before the sheet closes.
    let onChoose: (RunMode) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer()
                if app.location.isDenied {
                    deniedContent
                } else {
                    waitingContent
                }
                Spacer()
            }
            .padding()
            .navigationTitle("Outdoor run")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        app.location.stop()
                        dismiss()
                    }
                }
            }
            .onAppear { prepareLocation() }
            .onChange(of: app.location.authorization) { _, _ in prepareLocation() }
        }
        .interactiveDismissDisabled()
    }

    private func hasFix(at now: Date) -> Bool {
        guard let latest = app.location.latest else { return false }
        return SampleFilter.accepts(latest, now: now)
    }

    /// Re-evaluated every second as well as on each fix, so a fix that goes stale after GPS was
    /// ready (stepping indoors, say) disables Start again.
    private var waitingContent: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let ready = hasFix(at: context.date)
            VStack(spacing: 16) {
                if ready {
                    Image(systemName: "location.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.green)
                    Text("GPS ready").font(.title2.bold())
                } else {
                    ProgressView().controlSize(.large)
                    Text("Waiting for GPS…").font(.title2.bold())
                    Text(accuracyText(at: context.date))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                Button {
                    choose(.outdoor)
                } label: {
                    Text("Start").font(.title3.bold()).frame(maxWidth: .infinity).padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!ready)
                if app.location.isReducedAccuracy {
                    Button("Open Settings") { openSettings() }
                }
                Button("Use treadmill instead") { choose(.treadmill) }
            }
        }
    }

    private func accuracyText(at now: Date) -> String {
        if app.location.isReducedAccuracy {
            return "Precise Location is off for RunPlan. Turn it on in Settings so distance and pace can be measured."
        }
        guard let latest = app.location.latest, latest.horizontalAccuracy >= 0 else {
            return "Head outside with a clear view of the sky."
        }
        if latest.horizontalAccuracy <= SampleFilter.maxAccuracyMeters {
            // Accurate enough but too old: CoreLocation often hands over a cached fix first.
            return "Waiting for a fresh fix…"
        }
        return "Accuracy \(Int(latest.horizontalAccuracy)) m. Ready at \(Int(SampleFilter.maxAccuracyMeters)) m."
    }

    private var deniedContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "location.slash")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Location is off for RunPlan").font(.title2.bold())
            Text("Outdoor runs need your location to measure distance and pace. Turn it on in Settings, or do this run in treadmill mode.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Open Settings") { openSettings() }
            Button {
                choose(.treadmill)
            } label: {
                Text("Use treadmill instead").frame(maxWidth: .infinity).padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func prepareLocation() {
        if app.location.needsPermission {
            app.location.requestPermission()
        } else {
            app.location.start()
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            openURL(url)
        }
    }

    private func choose(_ mode: RunMode) {
        // Re-check at the tap: the fix may have gone stale since the last refresh.
        if mode == .outdoor, !hasFix(at: Date()) {
            return
        }
        if mode == .treadmill {
            app.location.stop()
        }
        onChoose(mode)
        dismiss()
    }
}
