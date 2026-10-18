import Foundation

/// Decides whether a GPS fix is good enough to use: accurate to 20 m and at most 5 s old.
public enum SampleFilter {
    public static let maxAccuracyMeters = 20.0
    public static let maxAgeSeconds: TimeInterval = 5

    public static func accepts(_ sample: LocationSample, now: Date) -> Bool {
        sample.horizontalAccuracy >= 0
            && sample.horizontalAccuracy <= maxAccuracyMeters
            && now.timeIntervalSince(sample.timestamp) <= maxAgeSeconds
    }
}
