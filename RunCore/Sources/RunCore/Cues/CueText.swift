import Foundation

/// Wording for spoken cues and on-screen targets.
public enum CueText {

    /// e.g. "Run, 4.7 miles per hour, 1 minute 30 seconds."
    public static func announcement(for step: FlatStep, mode: RunMode) -> String {
        var parts = [spokenKind(step.kind)]
        if let pace = step.targetPaceSecondsPerMile {
            parts.append(spokenTarget(pace: pace, mode: mode))
        }
        if let seconds = step.durationSeconds {
            parts.append(spokenDuration(seconds))
        } else if let meters = step.distanceMeters {
            parts.append("\(decimal(Pace.miles(fromMeters: meters))) miles")
        }
        return parts.joined(separator: ", ") + "."
    }

    /// Short on-screen target, e.g. "4.7 mph" or "12:46 /mi". nil when the step has no target.
    public static func target(for step: FlatStep, mode: RunMode) -> String? {
        guard let pace = step.targetPaceSecondsPerMile else { return nil }
        switch mode {
        case .treadmill: return "\(decimal(Pace.mph(fromSecondsPerMile: pace))) mph"
        case .outdoor: return "\(Pace.clock(pace)) /mi"
        }
    }

    public static func displayKind(_ kind: StepKind) -> String {
        switch kind {
        case .warmup: return "Warm up"
        case .run: return "Run"
        case .walk: return "Walk"
        case .recovery: return "Recover"
        case .cooldown: return "Cool down"
        }
    }

    private static func spokenKind(_ kind: StepKind) -> String {
        displayKind(kind)
    }

    private static func spokenTarget(pace: Int, mode: RunMode) -> String {
        switch mode {
        case .treadmill:
            return "\(decimal(Pace.mph(fromSecondsPerMile: pace))) miles per hour"
        case .outdoor:
            return "\(spokenDuration(pace)) per mile"
        }
    }

    private static func spokenDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainder = seconds % 60
        let minuteText = "\(minutes) minute\(minutes == 1 ? "" : "s")"
        let secondText = "\(remainder) second\(remainder == 1 ? "" : "s")"
        if minutes == 0 { return secondText }
        if remainder == 0 { return minuteText }
        return "\(minuteText) \(secondText)"
    }

    /// One decimal place, dropping a trailing ".0".
    private static func decimal(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        return rounded.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", rounded)
            : String(format: "%.1f", rounded)
    }
}
