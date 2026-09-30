import Foundation
import SwiftData
import Testing
@testable import ALSpeak

@MainActor
struct SpeechCoordinatorTests {
    let container: ModelContainer
    let synth = MockSynthesizer()
    let haptics = MockHaptics()
    let coordinator: SpeechCoordinator
    var context: ModelContext { container.mainContext }

    init() throws {
        container = try AppSchema.makeContainer(inMemory: true)
        let speech = SpeechService(synthesizer: synth, audioSession: MockAudioSession())
        coordinator = SpeechCoordinator(speech: speech, context: container.mainContext, haptics: haptics)
        UserSettings.current(in: container.mainContext).tokens = ["name": "Sam", "caregiverName": ""]
    }

    @Test func speakingPhraseResolvesTokensAndRecordsUse() {
        let phrase = Phrase(text: "My name is {name}")
        context.insert(phrase)

        coordinator.speak(phrase)

        #expect(synth.spoken.map(\.speechString) == ["My name is Sam"])
        #expect(phrase.useCount == 1)
        #expect(phrase.lastUsedAt != nil)
        #expect(haptics.spokenCount == 1)
        #expect(coordinator.displayedText == "My name is Sam")
    }

    @Test func missingTokensAreDroppedFromSpeechButFlaggedForDisplay() {
        let phrase = Phrase(text: "Get my caregiver {caregiverName}")
        context.insert(phrase)

        coordinator.speak(phrase)

        #expect(synth.spoken.first?.speechString == "Get my caregiver")
        #expect(coordinator.displayText(for: phrase) == "Get my caregiver {caregiverName}")
        #expect(coordinator.missingTokens(for: phrase) == ["caregiverName"])
    }

    @Test func appliesVoiceSettingsFromUserSettings() {
        let settings = UserSettings.current(in: context)
        settings.speechRate = 0.3
        settings.pitch = 1.4

        coordinator.speak(text: "Hello")

        #expect(synth.spoken.first?.rate == 0.3)
        #expect(synth.spoken.first?.pitchMultiplier == 1.4)
    }

    @Test func textThatIsOnlyMissingTokensSpeaksNothing() {
        coordinator.speak(text: "{caregiverName}")
        #expect(synth.spoken.isEmpty)
        #expect(haptics.spokenCount == 0)
        #expect(coordinator.displayedText == nil)
    }

    @Test func repeatSpeaksDisplayedTextAgain() {
        coordinator.speak(text: "Hello")
        coordinator.repeatDisplayed()
        #expect(synth.spoken.map(\.speechString) == ["Hello", "Hello"])
    }

    @Test func dismissHidesOverlay() {
        coordinator.speak(text: "Hello")
        coordinator.dismissDisplay()
        #expect(coordinator.displayedText == nil)
    }

    @Test func overlayHidesAutomaticallyAfterSpeechEnds() async throws {
        coordinator.minimumDisplayTime = .milliseconds(10)
        coordinator.lingerAfterSpeech = .milliseconds(10)

        coordinator.speak(text: "Hello")
        coordinator.speech.utteranceEnded(ObjectIdentifier(synth.spoken[0]))

        for _ in 0..<100 where coordinator.displayedText != nil {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(coordinator.displayedText == nil)
    }

    @Test func overlayStaysWhileStillSpeaking() async throws {
        coordinator.minimumDisplayTime = .milliseconds(10)
        coordinator.lingerAfterSpeech = .milliseconds(10)

        coordinator.speak(text: "Hello")
        try await Task.sleep(for: .milliseconds(150))
        #expect(coordinator.displayedText == "Hello")
    }
}
