import Foundation

public enum WorkoutKind: String, Codable, CaseIterable, Sendable {
    case walkRun
    case easy
    case intervals
    case tempo
    case longRun
    case timeTrial
}
