import Foundation

/// A generated training plan and the profile it was generated from.
public struct Plan: Codable, Equatable, Sendable {
    public var profile: Profile
    public var weeks: [Week]

    public init(profile: Profile, weeks: [Week]) {
        self.profile = profile
        self.weeks = weeks
    }
}
