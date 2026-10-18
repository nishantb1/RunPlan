import Foundation

/// Pace over the last 15 seconds of used fixes.
public struct PaceSmoother: Codable, Equatable, Sendable {
    public static let windowSeconds: TimeInterval = 15
    static let minimumSpanSeconds: TimeInterval = 5
    static let minimumMeters = 5.0

    struct Entry: Codable, Equatable, Sendable {
        let time: Date
        let meters: Double
    }

    private var entries: [Entry] = []

    public init() {}

    public mutating func add(time: Date, totalMeters: Double) {
        entries.append(Entry(time: time, meters: totalMeters))
        entries.removeAll { time.timeIntervalSince($0.time) > Self.windowSeconds }
    }

    public mutating func reset() {
        entries.removeAll()
    }

    /// Seconds per mile, or nil until the window holds at least 5 s and 5 m. It does not age
    /// by itself, so callers must ignore it once GPS has been lost.
    public var secondsPerMile: Int? {
        guard let first = entries.first, let last = entries.last else { return nil }
        let seconds = last.time.timeIntervalSince(first.time)
        let meters = last.meters - first.meters
        guard seconds >= Self.minimumSpanSeconds, meters >= Self.minimumMeters else { return nil }
        return Int((seconds / Pace.miles(fromMeters: meters)).rounded())
    }
}
