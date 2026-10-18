import Foundation

/// Decides whether a GPS fix is good enough to use: accurate to 20 m, at most 5 s old, and not
/// dated in the future. A future-dated fix would make every later fix look older than it and
/// freeze distance for the rest of the run.
public enum SampleFilter {
    public static let maxAccuracyMeters = 20.0
    public static let maxAgeSeconds: TimeInterval = 5
    /// Allowance for a fix stamped slightly after the `now` its caller captured.
    public static let maxClockSkewSeconds: TimeInterval = 1

    public static func accepts(_ sample: LocationSample, now: Date) -> Bool {
        let age = now.timeIntervalSince(sample.timestamp)
        return sample.horizontalAccuracy >= 0
            && sample.horizontalAccuracy <= maxAccuracyMeters
            && age >= -maxClockSkewSeconds
            && age <= maxAgeSeconds
    }
}
