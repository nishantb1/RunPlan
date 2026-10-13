import Foundation

public enum CueEvent: Equatable, Sendable {
    case announce(FlatStep)
    case countdownBeep
    case finished
}
