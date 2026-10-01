import Foundation
import Observation
import SwiftData

/// The single entry point views use to "say" something.
///
/// Speaking a phrase involves several steps that must always happen together:
/// fill in personal tokens → apply voice settings → speak → haptic → show the text
/// full-screen for the listener → record usage. Keeping them here means every button
/// (phrase board, favorites, and later Quick Respond and type-to-speak) behaves identically.
@MainActor
@Observable
final class SpeechCoordinator {
    let speech: SpeechService
    /// Text currently shown full-screen for the listener; nil when the overlay is hidden.
    private(set) var displayedText: String?

    @ObservationIgnored private let context: ModelContext
    @ObservationIgnored private let haptics: HapticsProviding
    @ObservationIgnored private var dismissTask: Task<Void, Never>?

    /// Minimum time the spoken text stays on screen, and how long it lingers after speech ends.
    @ObservationIgnored var minimumDisplayTime: Duration = .seconds(2)
    @ObservationIgnored var lingerAfterSpeech: Duration = .seconds(1.5)

    /// - Parameter haptics: Defaults to real device haptics (nil because a main-actor default
    ///   argument can't be evaluated in the caller's context).
    init(speech: SpeechService, context: ModelContext, haptics: HapticsProviding? = nil) {
        self.speech = speech
        self.context = context
        self.haptics = haptics ?? Haptics()
    }

    private var settings: UserSettings {
        UserSettings.current(in: context)
    }

    // MARK: Speaking

    /// Speaks a stored phrase and records that it was used.
    func speak(_ phrase: Phrase) {
        phrase.markUsed()
        try? context.save()
        speak(text: phrase.text)
    }

    /// Speaks arbitrary text (may contain tokens).
    func speak(text: String) {
        let settings = settings
        let spoken = TokenResolver.resolveForSpeech(text, tokens: settings.tokens)
        guard !spoken.isEmpty else { return }

        speech.voice = VoiceSettings(settings)
        speech.speak(spoken)
        haptics.phraseSpoken()
        show(spoken)
    }

    /// Repeats whatever is currently on screen (for a listener who missed it).
    func repeatDisplayed() {
        guard let displayedText else { return }
        speech.voice = VoiceSettings(settings)
        speech.speak(displayedText)
        haptics.phraseSpoken()
        show(displayedText)
    }

    /// Speaks text for checking how it sounds (e.g. in the phrase editor): no overlay,
    /// no haptic, no usage recorded.
    func preview(text: String) {
        let settings = settings
        let spoken = TokenResolver.resolveForSpeech(text, tokens: settings.tokens)
        guard !spoken.isEmpty else { return }
        speech.voice = VoiceSettings(settings)
        speech.speak(spoken)
    }

    /// Token names the user can insert into phrases (keys of `UserSettings.tokens`).
    var availableTokens: [String] {
        settings.tokens.keys.sorted()
    }

    func stopSpeaking() {
        speech.stop()
    }

    // MARK: Display helpers

    /// Text to put on a phrase button: tokens filled in where values exist.
    func displayText(for phrase: Phrase) -> String {
        TokenResolver.resolve(phrase.text, tokens: settings.tokens)
    }

    /// Tokens this phrase uses that have no value yet (shown as a hint to set them up).
    func missingTokens(for phrase: Phrase) -> [String] {
        TokenResolver.missingTokens(in: phrase.text, tokens: settings.tokens)
    }

    // MARK: Full-screen overlay

    func dismissDisplay() {
        dismissTask?.cancel()
        displayedText = nil
    }

    /// Shows the text and hides it automatically once speech has ended and the listener
    /// has had a moment to finish reading.
    private func show(_ text: String) {
        displayedText = text
        dismissTask?.cancel()
        dismissTask = Task { [weak self, minimumDisplayTime, lingerAfterSpeech] in
            do {
                try await Task.sleep(for: minimumDisplayTime)
                while self?.speech.isSpeaking == true {
                    try await Task.sleep(for: .milliseconds(200))
                }
                try await Task.sleep(for: lingerAfterSpeech)
            } catch {
                return // cancelled: a newer phrase took over the overlay
            }
            self?.displayedText = nil
        }
    }
}
