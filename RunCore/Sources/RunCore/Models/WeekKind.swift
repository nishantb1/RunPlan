import Foundation

/// `.cutback` is an easier week every fourth week; `.taper` is the last week, ending in the
/// time trial.
public enum WeekKind: String, Codable, CaseIterable, Sendable {
    case build
    case cutback
    case taper

    public var displayName: String {
        switch self {
        case .build: return "Build"
        case .cutback: return "Cutback"
        case .taper: return "Taper"
        }
    }
}
