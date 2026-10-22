import AVFoundation

/// Speaks cues and plays countdown beeps. The playback category keeps the app's audio alive in
/// the background, mixed over music. Other audio is ducked only while a cue is being spoken:
/// iOS restores ducked audio only when the ducking session deactivates, so ducking for the
/// whole workout would leave music lowered after the first cue.
final class AudioCueService: NSObject, AVSpeechSynthesizerDelegate {

    private let synthesizer = AVSpeechSynthesizer()
    private var beepPlayer: AVAudioPlayer?
    /// Loops silence for the whole workout. An active session that plays nothing does not stop
    /// iOS suspending the app, and on the treadmill there are no location updates to keep it
    /// running, so without this no cue would play while another app is open.
    private var keepAlivePlayer: AVAudioPlayer?
    /// Utterances queued or speaking. Music is restored when this drops back to zero.
    private var pendingUtterances = 0
    private var isActive = false

    override init() {
        super.init()
        beepPlayer = Self.makePlayer(named: "beep")
        keepAlivePlayer = Self.makePlayer(named: "silence")
        keepAlivePlayer?.numberOfLoops = -1
        keepAlivePlayer?.volume = 0
        synthesizer.delegate = self
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )
    }

    func activate() {
        isActive = true
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, options: [.mixWithOthers])
        try? session.setActive(true)
        keepAlivePlayer?.play()
    }

    func deactivate() {
        isActive = false
        keepAlivePlayer?.stop()
        synthesizer.stopSpeaking(at: .immediate)
        pendingUtterances = 0
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func speak(_ text: String) {
        if pendingUtterances == 0 {
            duckOthers()
        }
        pendingUtterances += 1
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        synthesizer.speak(utterance)
    }

    /// A bundled tone rather than a system sound, so it plays with the silent switch on.
    func playCountdownBeep() {
        beepPlayer?.currentTime = 0
        beepPlayer?.play()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        utteranceEnded()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        utteranceEnded()
    }

    private func utteranceEnded() {
        guard pendingUtterances > 0 else { return }
        pendingUtterances -= 1
        if pendingUtterances == 0 {
            restoreOthers()
        }
    }

    private func duckOthers() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, options: [.duckOthers])
        try? session.setActive(true)
    }

    /// Deactivating is what tells other apps to unduck; the session is then reactivated mixing.
    /// The silent loop is paused across the switch, since a session with running audio cannot be
    /// deactivated cleanly, and started again straight after so the app keeps running.
    private func restoreOthers() {
        guard isActive else { return }
        let session = AVAudioSession.sharedInstance()
        keepAlivePlayer?.pause()
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
        try? session.setCategory(.playback, options: [.mixWithOthers])
        try? session.setActive(true)
        keepAlivePlayer?.play()
    }

    /// A phone call or alarm stops our audio. Once it ends, start the silent loop again, or the
    /// app would be suspended for the rest of a treadmill run.
    @objc private func handleInterruption(_ notification: Notification) {
        guard isActive,
              let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              AVAudioSession.InterruptionType(rawValue: raw) == .ended else { return }
        DispatchQueue.main.async { [self] in
            guard isActive else { return }
            try? AVAudioSession.sharedInstance().setActive(true)
            keepAlivePlayer?.play()
        }
    }

    private static func makePlayer(named name: String) -> AVAudioPlayer? {
        guard let url = Bundle.module.url(forResource: name, withExtension: "wav") else { return nil }
        return try? AVAudioPlayer(contentsOf: url)
    }
}
