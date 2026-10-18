import SwiftUI
import RunCore

/// One step's controls: kind, length, an optional treadmill speed target, and, on the first
/// step of a repeat group, the group's repeat count.
struct StepEditor: View {
    @Binding var step: Step
    /// Non-nil only on the first step of a repeat group.
    let repeatCount: Binding<Int>?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Kind", selection: $step.kind) {
                ForEach(StepKind.allCases, id: \.self) { Text(CueText.displayKind($0)).tag($0) }
            }

            switch step.measure {
            case .time(let seconds):
                Stepper(Pace.clock(seconds), value: timeSeconds, in: 15...7200, step: 15)
            case .distance(let meters):
                Stepper(String(format: "%.2f mi", Pace.miles(fromMeters: meters)), value: distanceMiles, in: 0.05...26.2, step: 0.05)
            case .open:
                Text("Until you end the run").foregroundStyle(.secondary)
            }

            Toggle("Speed target", isOn: hasTarget)
            if let pace = step.targetPaceSecondsPerMile {
                Stepper(
                    "\(String(format: "%.1f", Pace.mph(fromSecondsPerMile: pace))) mph · \(Pace.clock(pace)) /mi",
                    value: targetMph,
                    in: 1.0...15.0,
                    step: 0.1
                )
            }

            if let repeatCount {
                Stepper("Repeat \(repeatCount.wrappedValue) ×", value: repeatCount, in: 1...20)
            }
        }
        .padding(.vertical, 4)
    }

    private var timeSeconds: Binding<Int> {
        Binding(
            get: {
                if case .time(let seconds) = step.measure { return seconds }
                return 0
            },
            set: { step.measure = .time(seconds: $0) }
        )
    }

    private var distanceMiles: Binding<Double> {
        Binding(
            get: {
                if case .distance(let meters) = step.measure { return Pace.miles(fromMeters: meters) }
                return 0
            },
            set: { step.measure = .distance(meters: Pace.meters(fromMiles: $0)) }
        )
    }

    /// Turning the target on starts it at 5.0 mph.
    private var hasTarget: Binding<Bool> {
        Binding(
            get: { step.targetPaceSecondsPerMile != nil },
            set: { step.targetPaceSecondsPerMile = $0 ? Pace.secondsPerMile(fromMph: 5.0) : nil }
        )
    }

    /// Read rounded to 0.1 mph, so each press moves one treadmill increment.
    private var targetMph: Binding<Double> {
        Binding(
            get: { Pace.mph(fromSecondsPerMile: step.targetPaceSecondsPerMile ?? 0) },
            set: { step.targetPaceSecondsPerMile = Pace.secondsPerMile(fromMph: $0) }
        )
    }
}
