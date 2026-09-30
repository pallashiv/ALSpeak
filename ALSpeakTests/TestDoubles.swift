import AVFoundation
@testable import ALSpeak

/// Records utterances instead of speaking them.
final class MockSynthesizer: SpeechSynthesizing {
    weak var delegate: (any AVSpeechSynthesizerDelegate)?
    private(set) var spoken: [AVSpeechUtterance] = []
    private(set) var stopCount = 0

    func speak(_ utterance: AVSpeechUtterance) {
        spoken.append(utterance)
    }

    func stopSpeaking(at boundary: AVSpeechBoundary) -> Bool {
        stopCount += 1
        return true
    }
}

final class MockAudioSession: AudioSessionControlling {
    private(set) var activateCount = 0
    private(set) var deactivateCount = 0

    func activate() { activateCount += 1 }
    func deactivate() { deactivateCount += 1 }
}

@MainActor
final class MockHaptics: HapticsProviding {
    private(set) var spokenCount = 0
    private(set) var emergencyCount = 0

    func phraseSpoken() { spokenCount += 1 }
    func emergency() { emergencyCount += 1 }
}
