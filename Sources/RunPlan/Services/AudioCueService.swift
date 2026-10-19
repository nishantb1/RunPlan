import AVFoundation

/// Speaks cues and plays countdown beeps. The playback category keeps the app's audio alive in
/// the background; with spoken cues it ducks other audio so they can be heard over music.
final class AudioCueService {

    private let synthesizer = AVSpeechSynthesizer()
    private var beepPlayer: AVAudioPlayer?

    init() {
        beepPlayer = Self.makeBeepPlayer()
    }

    /// With `duckingOthers` false (voice cues off) the beeps mix over music without lowering it.
    func activate(duckingOthers: Bool) {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, options: duckingOthers ? [.duckOthers] : [.mixWithOthers])
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
