import SwiftUI
import RunCore

/// Large, glanceable and high contrast: readable at arm's length on a treadmill console or
/// mid-stride outdoors. Outdoors it adds distance, pace and a GPS warning.
struct LiveWorkoutView: View {
    let session: WorkoutSessionModel

    @State private var confirmingEnd = false

    private var isOutdoor: Bool { session.mode == .outdoor }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let snapshot = session.snapshot {
                VStack(spacing: isOutdoor ? 14 : 20) {
                    if snapshot.stepCount > 1 {
                        Text("Step \(snapshot.stepIndex + 1) of \(snapshot.stepCount)")
                            .font(.headline)
                            .foregroundStyle(.gray)
                    }

                    Text(CueText.displayKind(snapshot.step.kind).uppercased())
                        .font(.system(size: isOutdoor ? 52 : 64, weight: .heavy))
                        .foregroundStyle(color(for: snapshot.step.kind))
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)

                    Text(CueText.target(for: snapshot.step, mode: session.mode) ?? "No target")
                        .font(.system(size: isOutdoor ? 56 : 72, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)

                    Text(clock(for: snapshot))
                        .font(.system(size: isOutdoor ? 72 : 88, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)

                    if isOutdoor {
                        outdoorStats
                    }

                    progress(snapshot)

                    if snapshot.stepCount > 1 {
                        Text(nextText(snapshot))
                            .font(.title3)
                            .foregroundStyle(.gray)
                    }

                    Spacer()

                    controls(snapshot)
                }
                .padding()
            }
        }
        .confirmationDialog("End this workout?", isPresented: $confirmingEnd, titleVisibility: .visible) {
            Button("End workout", role: .destructive) { session.endEarly() }
        }
    }

    private var outdoorStats: some View {
        VStack(spacing: 8) {
            if !session.hasSignal() {
                Label("GPS signal lost. Distance is paused.", systemImage: "location.slash")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.yellow, in: Capsule())
            }
            HStack(spacing: 40) {
                stat(String(format: "%.2f", Pace.miles(fromMeters: session.distanceMeters)), label: "miles")
                stat(session.currentPace.map { Pace.clock($0) } ?? "--:--", label: "pace /mi")
            }
        }
    }

    private func stat(_ value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 40, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(.white)
            Text(label)
                .font(.caption)
                .foregroundStyle(.gray)
        }
    }

    @ViewBuilder
    private func progress(_ snapshot: WorkoutEngine.Snapshot) -> some View {
        if snapshot.totalPlanned > 0 {
            ProgressView(value: min(snapshot.totalElapsed, snapshot.totalPlanned), total: snapshot.totalPlanned)
                .tint(.white)

            Text("\(Pace.clock(Int(snapshot.totalElapsed))) of \(Pace.clock(Int(snapshot.totalPlanned)))")
                .font(.headline)
                .monospacedDigit()
                .foregroundStyle(.gray)
        } else {
            Text("\(Pace.clock(Int(snapshot.totalElapsed))) elapsed")
                .font(.headline)
                .monospacedDigit()
                .foregroundStyle(.gray)
        }
    }

    private func controls(_ snapshot: WorkoutEngine.Snapshot) -> some View {
        HStack(spacing: 24) {
            controlButton("backward.end.fill") { session.skipBack() }
            controlButton(session.isPaused ? "play.fill" : "pause.fill") {
                if session.isPaused { session.resume() } else { session.pause() }
            }
            // On the last step, skipping forward would end the run without asking; Stop asks.
            controlButton("forward.end.fill", enabled: snapshot.nextStep != nil) { session.skipForward() }
            controlButton("stop.fill") { confirmingEnd = true }
        }
    }

    private func controlButton(_ systemName: String, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 30))
                .frame(width: 72, height: 72)
                .background(Color.white.opacity(0.15), in: Circle())
                .foregroundStyle(.white)
        }
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.3)
    }

    /// Countdown for a timed step, distance left for a distance step outdoors, otherwise
    /// count-up.
    private func clock(for snapshot: WorkoutEngine.Snapshot) -> String {
        if let remaining = snapshot.remainingInStep {
            return Pace.clock(Int(remaining.rounded(.up)))
        }
        if let meters = session.stepMetersRemaining {
            return String(format: "%.2f mi", Pace.miles(fromMeters: meters))
        }
        return Pace.clock(Int(snapshot.elapsedInStep))
    }

    private func nextText(_ snapshot: WorkoutEngine.Snapshot) -> String {
        guard let next = snapshot.nextStep else { return "Last step" }
        let kind = CueText.displayKind(next.kind)
        guard let target = CueText.target(for: next, mode: session.mode) else { return "Next: \(kind)" }
        return "Next: \(kind) at \(target)"
    }

    private func color(for kind: StepKind) -> Color {
        switch kind {
        case .run: return .green
        case .walk, .recovery: return .yellow
        case .warmup, .cooldown: return .cyan
        }
    }
}
