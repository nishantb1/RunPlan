import Foundation

/// What an outdoor session should do after a snapshot.
public enum OutdoorEvent: Equatable, Sendable {
    /// Announce a completed mile.
    case split(Split)
    case paceCue(PaceCue)
    /// The current distance step's distance has been covered: advance the engine.
    case stepDistanceReached
}
