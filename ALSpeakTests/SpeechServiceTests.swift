import AVFoundation
import Testing
@testable import ALSpeak

@MainActor
struct SpeechServiceTests {
    let synth = MockSynthesizer()
    let audio = MockAudioSession()
    let service: SpeechService

    init() {
        service = SpeechService(synthesizer: synth, audioSession: audio)
    }

    /// Simulates the synthesizer reporting that an utterance finished (or was cancelled).
    private func finish(_ index: Int) {
        service.utteranceEnded(ObjectIdentifier(synth.spoken[index]))
    }

    // MARK: Speaking

    @Test func setsItselfAsDelegate() {
        #expect(synth.delegate === service)
    }

    @Test func speakAppliesVoiceSettings() throws {
        service.voice = VoiceSettings(voiceIdentifier: nil, rate: 0.4, pitch: 1.3, volume: 0.7)
        service.speak("Hello")

        let utterance = try #require(synth.spoken.first)
        #expect(utterance.speechString == "Hello")
        #expect(utterance.rate == 0.4)
        #expect(utterance.pitchMultiplier == 1.3)
        #expect(utterance.volume == 0.7)
        #expect(utterance.voice != nil)
    }

    @Test func outOfRangeVoiceValuesAreClamped() throws {
        service.voice = VoiceSettings(voiceIdentifier: nil, rate: 9, pitch: 0, volume: -1)
        service.speak("Hello")

        let utterance = try #require(synth.spoken.first)
        #expect(utterance.rate == AVSpeechUtteranceMaximumSpeechRate)
        #expect(utterance.pitchMultiplier == 0.5)
        #expect(utterance.volume == 0)
    }

    @Test func unknownVoiceIdentifierFallsBackToDefaultVoice() throws {
        service.voice.voiceIdentifier = "not.a.real.voice"
        service.speak("Hello")
        #expect(try #require(synth.spoken.first).voice != nil)
    }

    @Test func blankTextIsIgnored() {
        service.speak("   \n")
        #expect(synth.spoken.isEmpty)
        #expect(!service.isSpeaking)
    }

    @Test func textIsTrimmed() {
        service.speak("  Hello  ")
        #expect(synth.spoken.first?.speechString == "Hello")
    }

    // MARK: State

    @Test func isSpeakingFollowsUtteranceLifecycle() {
        #expect(!service.isSpeaking)
        service.speak("Hello")
        #expect(service.isSpeaking)
        #expect(service.currentText == "Hello")

        finish(0)
        #expect(!service.isSpeaking)
        #expect(service.currentText == nil)
    }

    // MARK: Interrupt vs. queue

    @Test func speakInterruptsCurrentSpeech() {
        service.speak("First")
        service.speak("Second")
        #expect(synth.stopCount == 1)
        #expect(service.currentText == "Second")
    }

    @Test func speakingWhenIdleDoesNotCallStop() {
        service.speak("First")
        #expect(synth.stopCount == 0)
    }

    @Test func lateCancelOfInterruptedPhraseDoesNotEndNewPhrase() {
        service.speak("First")
        service.speak("Second")
        finish(0) // synthesizer's cancel callback for "First" arrives after "Second" started
        #expect(service.isSpeaking)
        #expect(service.currentText == "Second")
    }

    @Test func enqueueWaitsForCurrentSpeech() {
        service.speak("First")
        service.enqueue("Second")
        #expect(synth.stopCount == 0)
        #expect(synth.spoken.map(\.speechString) == ["First", "Second"])

        finish(0)
        #expect(service.isSpeaking)
        #expect(service.currentText == "Second")

        finish(1)
        #expect(!service.isSpeaking)
    }

    @Test func stopClearsEverything() {
        service.speak("First")
        service.enqueue("Second")
        service.stop()
        #expect(synth.stopCount == 1)
        #expect(!service.isSpeaking)
        #expect(service.currentText == nil)
    }

    @Test func stopWhenIdleIsNoOp() {
        service.stop()
        #expect(synth.stopCount == 0)
    }

    // MARK: Emergency

    @Test func emergencyInterruptsAndRepeatsAtFullVolume() {
        service.voice = VoiceSettings(voiceIdentifier: nil, rate: 0.6, pitch: 1, volume: 0.2)
        service.speak("Chatting")
        service.speakEmergency("Help me", repeatCount: 3)

        #expect(synth.stopCount == 1)
        let emergency = synth.spoken.dropFirst()
        #expect(emergency.count == 3)
        #expect(emergency.allSatisfy { $0.speechString == "Help me" && $0.volume == 1.0 })
        #expect(emergency.allSatisfy { $0.rate <= AVSpeechUtteranceDefaultSpeechRate })
        // The user's own volume setting is untouched.
        #expect(service.voice.volume == 0.2)
    }

    @Test func emergencySpeaksAtLeastOnce() {
        service.speakEmergency("Help me", repeatCount: 0)
        #expect(synth.spoken.count == 1)
    }

    // MARK: Audio session

    @Test func audioSessionActivatesOnceAndDeactivatesWhenQueueEmpties() {
        service.speak("First")
        service.enqueue("Second")
        #expect(audio.activateCount == 1)

        finish(0)
        #expect(audio.deactivateCount == 0)
        finish(1)
        #expect(audio.deactivateCount == 1)
    }

    @Test func audioSessionIsReleasedAfterStopOnceSynthesizerConfirms() {
        service.speak("First")
        service.stop()
        #expect(audio.deactivateCount == 0)
        finish(0) // didCancel
        #expect(audio.deactivateCount == 1)
    }
}
