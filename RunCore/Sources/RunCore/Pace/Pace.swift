import Foundation

/// Pace, speed and distance conversions. Targets are stored as seconds per mile; treadmill
/// mode shows the same target as mph.
public enum Pace {
    public static let metersPerMile = 1609.344

    /// Treadmill speed for a pace, rounded to the 0.1 mph a treadmill can be set to.
    public static func mph(fromSecondsPerMile seconds: Int) -> Double {
        guard seconds > 0 else { return 0 }
        return (36000.0 / Double(seconds)).rounded() / 10
    }

    public static func secondsPerMile(fromMph mph: Double) -> Int {
        guard mph > 0 else { return 0 }
        return Int((3600.0 / mph).rounded())
    }

    /// Average pace for a finished run, or nil when there is no distance to divide by.
    public static func secondsPerMile(distanceMeters: Double, durationSeconds: Int) -> Int? {
        guard distanceMeters > 0 else { return nil }
        return Int((Double(durationSeconds) / miles(fromMeters: distanceMeters)).rounded())
    }

    public static func miles(fromMeters meters: Double) -> Double {
        meters / metersPerMile
    }

    public static func meters(fromMiles miles: Double) -> Double {
        miles * metersPerMile
    }

    /// "m:ss", or "h:mm:ss" from one hour up. Used for both durations and paces.
    public static func clock(_ seconds: Int) -> String {
        let total = max(0, seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }
}
