import Foundation

/// The runner's preferences. A workout reads them once, when it starts.
public struct AppSettings: Codable, Equatable, Sendable {
    /// Keep the screen on during a workout.
    public var keepScreenAwake: Bool
    /// Speak step announcements, mile splits and pace cues. Countdown beeps and haptics play
    /// either way.
    public var voiceCues: Bool
    /// Outdoors, pause when the runner stops and resume when they set off again.
    public var autoPause: Bool

    public init(keepScreenAwake: Bool = true, voiceCues: Bool = true, autoPause: Bool = false) {
        self.keepScreenAwake = keepScreenAwake
        self.voiceCues = voiceCues
        self.autoPause = autoPause
    }

    /// Missing keys take their defaults, so settings saved by an older build still load.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = AppSettings()
        keepScreenAwake = try container.decodeIfPresent(Bool.self, forKey: .keepScreenAwake) ?? defaults.keepScreenAwake
        voiceCues = try container.decodeIfPresent(Bool.self, forKey: .voiceCues) ?? defaults.voiceCues
        autoPause = try container.decodeIfPresent(Bool.self, forKey: .autoPause) ?? defaults.autoPause
    }
}
