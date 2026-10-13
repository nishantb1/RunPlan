import SwiftUI
import RunCore

/// Large, glanceable and high contrast: readable at arm's length on a treadmill console.
struct LiveWorkoutView: View {
    let session: WorkoutSessionModel

    @State private var confirmingEnd = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let snapshot = session.snapshot {
                VStack(spacing: 20) {
                    Text("Step \(snapshot.stepIndex + 1) of \(snapshot.stepCount)")
                        .font(.headline)
                        .foregroundStyle(.gray)

                    Text(CueText.displayKind(snapshot.step.kind).uppercased())
                        .font(.system(size: 64, weight: .heavy))
                        .foregroundStyle(color(for: snapshot.step.kind))
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)

                    Text(CueText.target(for: snapshot.step, mode: session.mode) ?? "No target")
                        .font(.system(size: 72, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)

                    Text(clock(for: snapshot))
                        .font(.system(size: 88, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(.white)

                    ProgressView(value: min(snapshot.totalElapsed, max(snapshot.totalPlanned, 1)), total: max(snapshot.totalPlanned, 1))
                        .tint(.white)

                    Text("\(Pace.clock(Int(snapshot.totalElapsed))) of \(Pace.clock(Int(snapshot.totalPlanned)))")
                        .font(.headline)
                        .monospacedDigit()
                        .foregroundStyle(.gray)

                    Text(nextText(snapshot))
                        .font(.title3)
                        .foregroundStyle(.gray)

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

    private func controls(_ snapshot: WorkoutEngine.Snapshot) -> some View {
        HStack(spacing: 24) {
            controlButton("backward.end.fill") { session.skipBack() }
            controlButton(session.isPaused ? "play.fill" : "pause.fill") {
                if session.isPaused { session.resume() } else { session.pause() }
            }
            controlButton("forward.end.fill") { session.skipForward() }
            controlButton("stop.fill") { confirmingEnd = true }
        }
    }

    private func controlButton(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 30))
                .frame(width: 72, height: 72)
                .background(Color.white.opacity(0.15), in: Circle())
                .foregroundStyle(.white)
        }
    }

    /// Countdown for a timed step, count-up for a distance step.
    private func clock(for snapshot: WorkoutEngine.Snapshot) -> String {
        if let remaining = snapshot.remainingInStep {
            return Pace.clock(Int(remaining.rounded(.up)))
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
