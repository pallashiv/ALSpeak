import AVFoundation
import Observation
import os

/// Voice parameters applied to each utterance. Mirrors the voice fields of `UserSettings`
/// but is a plain value so `SpeechService` doesn't depend on SwiftData.
struct VoiceSettings: Equatable {
    /// `AVSpeechSynthesisVoice.identifier`; nil means the default voice for the current language.
    var voiceIdentifier: String?
    var rate: Float
    var pitch: Float
    var volume: Float

    static let standard = VoiceSettings(
        voiceIdentifier: nil,
        rate: AVSpeechUtteranceDefaultSpeechRate,
        pitch: 1.0,
        volume: 1.0
    )
}

extension VoiceSettings {
    init(_ settings: UserSettings) {
        self.init(
            voiceIdentifier: settings.voiceIdentifier,
            rate: settings.speechRate,
            pitch: settings.pitch,
            volume: settings.volume
        )
    }
}

/// The subset of `AVSpeechSynthesizer` that `SpeechService` uses, so tests can inject a fake.
protocol SpeechSynthesizing: AnyObject {
    var delegate: (any AVSpeechSynthesizerDelegate)? { get set }
    func speak(_ utterance: AVSpeechUtterance)
    @discardableResult func stopSpeaking(at boundary: AVSpeechBoundary) -> Bool
}

extension AVSpeechSynthesizer: SpeechSynthesizing {}

/// Wraps `AVSpeechSynthesizer` with the behaviour the app needs:
/// - `speak` interrupts whatever is playing (the default: the newest phrase wins),
/// - `enqueue` queues behind current speech,
/// - `stop` silences everything immediately,
/// - `isSpeaking` / `currentText` are observable for the UI.
///
/// Speech state is tracked per utterance, so a late "cancelled" callback from an
/// interrupted phrase can't mark a newer phrase as finished.
@MainActor
@Observable
final class SpeechService: NSObject {
    private(set) var isSpeaking = false
    /// Text of the utterance currently playing (or next up), for display.
    private(set) var currentText: String?
    /// Applied to every utterance created after it is set.
    var voice: VoiceSettings = .standard

    @ObservationIgnored private let synthesizer: SpeechSynthesizing
    @ObservationIgnored private let audioSession: AudioSessionControlling
    /// Utterances handed to the synthesizer that haven't finished or been cancelled, in order.
    @ObservationIgnored private var outstanding: [(id: ObjectIdentifier, text: String)] = []

    init(
        synthesizer: SpeechSynthesizing = AVSpeechSynthesizer(),
        audioSession: AudioSessionControlling = AudioSessionManager()
    ) {
        self.synthesizer = synthesizer
        self.audioSession = audioSession
        super.init()
        synthesizer.delegate = self
    }

    // MARK: Public API

    /// Speaks `text` now. By default this interrupts anything already playing, because a
    /// user tapping a new phrase mid-sentence almost always means "say this instead".
    func speak(_ text: String, interrupt: Bool = true) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if interrupt { stop() }
        start(makeUtterance(trimmed, voice: voice))
    }

    /// Queues `text` after whatever is currently playing.
    func enqueue(_ text: String) {
        speak(text, interrupt: false)
    }

    /// Interrupts everything and speaks `text` at full volume, `repeatCount` times.
    func speakEmergency(_ text: String, repeatCount: Int = 1) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        stop()
        var loud = voice
        loud.volume = 1.0
        // Never faster than the default rate, so an alarmed listener catches every word.
        loud.rate = min(voice.rate, AVSpeechUtteranceDefaultSpeechRate)
        for _ in 0..<max(1, repeatCount) {
            start(makeUtterance(trimmed, voice: loud))
        }
    }

    /// Stops all speech immediately and clears the queue.
    func stop() {
        guard !outstanding.isEmpty else { return }
        synthesizer.stopSpeaking(at: .immediate)
        outstanding.removeAll()
        refreshState()
        // The audio session is released when the synthesizer's cancel callback arrives
        // (see `utteranceEnded`), not here, because the audio engine may still be running.
    }

    // MARK: Utterances

    /// Builds an utterance with values clamped to AVFoundation's valid ranges.
    func makeUtterance(_ text: String, voice: VoiceSettings) -> AVSpeechUtterance {
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = voice.rate.clamped(to: AVSpeechUtteranceMinimumSpeechRate...AVSpeechUtteranceMaximumSpeechRate)
        utterance.pitchMultiplier = voice.pitch.clamped(to: 0.5...2.0)
        utterance.volume = voice.volume.clamped(to: 0...1)
        utterance.preUtteranceDelay = 0
        utterance.voice = voice.voiceIdentifier.flatMap(AVSpeechSynthesisVoice.init(identifier:))
            ?? AVSpeechSynthesisVoice(language: AVSpeechSynthesisVoice.currentLanguageCode())
        return utterance
    }

    private func start(_ utterance: AVSpeechUtterance) {
        if outstanding.isEmpty { audioSession.activate() }
        outstanding.append((ObjectIdentifier(utterance), utterance.speechString))
        refreshState()
        synthesizer.speak(utterance)
    }

    /// Called when the synthesizer finishes or cancels an utterance.
    /// Internal (not private) so tests can simulate synthesizer callbacks.
    func utteranceEnded(_ id: ObjectIdentifier) {
        outstanding.removeAll { $0.id == id }
        refreshState()
        if outstanding.isEmpty { audioSession.deactivate() }
    }

    private func refreshState() {
        isSpeaking = !outstanding.isEmpty
        currentText = outstanding.first?.text
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension SpeechService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor in self.utteranceEnded(id) }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor in self.utteranceEnded(id) }
    }
}

// MARK: - Helpers

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
