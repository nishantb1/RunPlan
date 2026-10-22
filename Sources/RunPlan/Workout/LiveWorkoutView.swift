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
                // The controls stay pinned at the bottom; everything above scrolls if a small
                // screen or large text would otherwise push them off.
                VStack(spacing: 12) {
                    ScrollView {
                        VStack(spacing: isOutdoor ? 14 : 20) {
                            if snapshot.stepCount > 1 {
                                Text("Step \(snapshot.stepIndex + 1) of \(snapshot.stepCount)")
                                    .font(.headline)
                                    .foregroundStyle(.gray)
                            }

                            if session.isAutoPaused {
                                Text("Auto-paused. Set off to resume.")
                                    .font(.headline)
                                    .foregroundStyle(.yellow)
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
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .scrollBounceBehavior(.basedOnSize)

                    controls(snapshot)
                }
                .padding()
            }
        }
        .confirmationDialog("End this workout?", isPresented: $confirmingEnd, titleVisibility: .visible) {
            Button("End workout", role: .destructive) { session.endEarly() }
        }
    }

    /// Re-checked every second: while paused nothing else redraws the screen, and the signal can
    /// still be lost.
    private var outdoorStats: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            outdoorStatsContent(now: context.date)
        }
    }

    private func outdoorStatsContent(now: Date) -> some View {
        VStack(spacing: 8) {
            if !session.hasSignal(now: now) {
                Label("GPS signal lost. Distance is paused.", systemImage: "location.slash")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
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
            Text("\(Pace.clock(Int(snapshot.activeElapsed))) elapsed")
                .font(.headline)
                .monospacedDigit()
                .foregroundStyle(.gray)
        }
    }

    private func controls(_ snapshot: WorkoutEngine.Snapshot) -> some View {
        HStack(spacing: 24) {
            // Back and Skip need a hold, so a stray tap mid-run cannot lose the current step.
            HoldControlButton(systemName: "backward.end.fill", label: "Back", hint: "Hold to go back a step.") {
                session.skipBack()
            }
            controlButton(session.isPaused ? "play.fill" : "pause.fill", label: session.isPaused ? "Resume" : "Pause") {
                if session.isPaused { session.resume() } else { session.pause() }
            }
            // On the last step, skipping forward would end the run without asking; Stop asks.
            HoldControlButton(systemName: "forward.end.fill", label: "Skip", hint: "Hold to skip to the next step.",
                              enabled: snapshot.nextStep != nil) {
                session.skipForward()
            }
            controlButton("stop.fill", label: "End workout") { confirmingEnd = true }
        }
    }

    private func controlButton(_ systemName: String, label: String, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 30))
                .frame(width: 72, height: 72)
                .background(Color.white.opacity(0.15), in: Circle())
                .foregroundStyle(.white)
        }
        .accessibilityLabel(label)
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

/// A control button that acts only after being held, with a ring that fills while held. Letting
/// go early does nothing. VoiceOver users activate it directly, as with any other button.
private struct HoldControlButton: View {
    let systemName: String
    let label: String
    let hint: String
    var enabled = true
    let action: () -> Void

    private static let holdDuration = 0.6

    @State private var fill: CGFloat = 0
    @State private var completions = 0

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 30))
            .frame(width: 72, height: 72)
            .background(Color.white.opacity(0.15), in: Circle())
            .overlay {
                Circle()
                    .trim(from: 0, to: fill)
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(2)
            }
            .foregroundStyle(.white)
            .contentShape(Circle())
            .onLongPressGesture(minimumDuration: Self.holdDuration) {
                completions += 1
                fill = 0
                action()
            } onPressingChanged: { pressing in
                if pressing {
                    withAnimation(.linear(duration: Self.holdDuration)) { fill = 1 }
                } else {
                    withAnimation(.easeOut(duration: 0.15)) { fill = 0 }
                }
            }
            .sensoryFeedback(.impact, trigger: completions)
            .disabled(!enabled)
            .opacity(enabled ? 1 : 0.3)
            .accessibilityElement()
            .accessibilityLabel(label)
            .accessibilityHint(hint)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction {
                if enabled { action() }
            }
    }
}
