import AVFoundation
import os

/// Abstraction over the shared audio session so `SpeechService` can be unit tested.
protocol AudioSessionControlling: AnyObject {
    func activate()
    func deactivate()
}

/// Configures `AVAudioSession` for speech output.
///
/// - `.playback` routes to the loudspeaker and **plays even when the ring/silent switch is
///   on silent**. This is deliberate: ALSpeak is the user's voice, and a phone left on silent
///   must not make them mute.
/// - `.spokenAudio` mode tells the system this is speech (better handling of interruptions).
/// - `.duckOthers` lowers music or podcasts while a phrase is spoken; they come back to
///   full volume when the session is deactivated.
final class AudioSessionManager: AudioSessionControlling {
    private let session: AVAudioSession
    private var isConfigured = false
    private let logger = Logger(subsystem: "com.shivpalla.ALSpeak", category: "audio")

    init(session: AVAudioSession = .sharedInstance()) {
        self.session = session
    }

    func activate() {
        do {
            if !isConfigured {
                try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
                isConfigured = true
            }
            try session.setActive(true)
        } catch {
            // Speech usually still works with the default session, so log rather than fail.
            logger.error("Audio session activation failed: \(error.localizedDescription)")
        }
    }

    func deactivate() {
        do {
            try session.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            logger.debug("Audio session deactivation failed: \(error.localizedDescription)")
        }
    }
}
