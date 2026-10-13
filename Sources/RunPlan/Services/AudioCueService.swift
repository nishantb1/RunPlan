import AVFoundation

/// Speaks cues and plays countdown beeps. The playback category with ducking lets cues play
/// over music and keeps the app's audio alive in the background.
final class AudioCueService {

    private let synthesizer = AVSpeechSynthesizer()
    private var beepPlayer: AVAudioPlayer?

    init() {
        beepPlayer = Self.makeBeepPlayer()
    }

    func activate() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, options: [.duckOthers])
        try? session.setActive(true)
    }

    func deactivate() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        synthesizer.speak(utterance)
    }

    /// A bundled tone rather than a system sound, so it plays with the silent switch on.
    func playCountdownBeep() {
        beepPlayer?.currentTime = 0
        beepPlayer?.play()
    }

    private static func makeBeepPlayer() -> AVAudioPlayer? {
        guard let url = Bundle.module.url(forResource: "beep", withExtension: "wav") else { return nil }
        return try? AVAudioPlayer(contentsOf: url)
    }
}
