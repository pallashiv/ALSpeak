import AVFoundation
import Foundation
import Observation

/// A voice the user can pick, decoupled from `AVSpeechSynthesisVoice` so filtering and
/// sorting can be unit tested.
struct VoiceOption: Identifiable, Equatable {
    enum Quality: Int, Comparable {
        case standard, enhanced, premium

        static func < (lhs: Quality, rhs: Quality) -> Bool { lhs.rawValue < rhs.rawValue }

        var label: String? {
            switch self {
            case .standard: nil
            case .enhanced: "Enhanced"
            case .premium: "Premium"
            }
        }
    }

    let id: String
    let name: String
    let language: String
    let quality: Quality
    let isPersonalVoice: Bool
    let isNovelty: Bool

    init(id: String, name: String, language: String, quality: Quality,
         isPersonalVoice: Bool = false, isNovelty: Bool = false) {
        self.id = id
        self.name = name
        self.language = language
        self.quality = quality
        self.isPersonalVoice = isPersonalVoice
        self.isNovelty = isNovelty
    }

    init(_ voice: AVSpeechSynthesisVoice) {
        let quality: Quality = switch voice.quality {
        case .premium: .premium
        case .enhanced: .enhanced
        default: .standard
        }
        self.init(
            id: voice.identifier,
            name: voice.name,
            language: voice.language,
            quality: quality,
            isPersonalVoice: voice.voiceTraits.contains(.isPersonalVoice),
            isNovelty: voice.voiceTraits.contains(.isNoveltyVoice)
        )
    }

    /// Readable language/region, e.g. "English (United Kingdom)".
    var languageName: String {
        Locale.current.localizedString(forIdentifier: language) ?? language
    }

    /// Voices worth offering: the user's Personal Voice(s) first, then voices in the user's
    /// language (best quality first). Novelty voices (Bells, Bubbles…) are left out.
    static func choices(from voices: [VoiceOption], languageCode: String) -> [VoiceOption] {
        let languagePrefix = languageCode.split(separator: "-").first.map(String.init) ?? languageCode
        return voices
            .filter { !$0.isNovelty && ($0.isPersonalVoice || $0.language.hasPrefix(languagePrefix)) }
            .sorted { lhs, rhs in
                if lhs.isPersonalVoice != rhs.isPersonalVoice { return lhs.isPersonalVoice }
                if lhs.quality != rhs.quality { return lhs.quality > rhs.quality }
                if lhs.language != rhs.language { return lhs.language == languageCode }
                return lhs.name.localizedCompare(rhs.name) == .orderedAscending
            }
    }
}

/// Converts between token keys used in phrases (`favoriteDrink`) and labels shown to people
/// ("Favorite drink").
enum TokenKey {
    /// "Pet's name" → "petsName". Returns nil if the label has no letters or digits.
    static func make(from label: String) -> String? {
        let words = label
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        guard let first = words.first else { return nil }
        return first.lowercased() + words.dropFirst().map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }.joined()
    }

    /// "favoriteDrink" → "Favorite drink"; the built-in "name" token reads as "Your name".
    static func displayName(for key: String) -> String {
        if key == "name" { return "Your name" }
        var words: [String] = []
        var current = ""
        for character in key {
            if character.isUppercase, !current.isEmpty {
                words.append(current)
                current = ""
            }
            current.append(character)
        }
        if !current.isEmpty { words.append(current) }
        let sentence = words.map { $0.lowercased() }.joined(separator: " ")
        return sentence.prefix(1).uppercased() + sentence.dropFirst()
    }
}

/// Settings screen state that isn't stored directly on `UserSettings`.
@MainActor
@Observable
final class SettingsViewModel {
    /// Range offered by the speed control. AVFoundation allows 0...1, but outside roughly
    /// this range speech becomes hard to follow.
    static let rateRange: ClosedRange<Float> = 0.3...0.65
    static let pitchRange: ClosedRange<Float> = 0.5...2.0
    static let volumeRange: ClosedRange<Float> = 0.1...1.0
    static let sampleSentence = "Hello, this is how I sound."

    private(set) var personalVoiceStatus: AVSpeechSynthesizer.PersonalVoiceAuthorizationStatus
    private(set) var voices: [VoiceOption] = []

    init() {
        personalVoiceStatus = AVSpeechSynthesizer.personalVoiceAuthorizationStatus
        reloadVoices()
    }

    func reloadVoices() {
        voices = VoiceOption.choices(
            from: AVSpeechSynthesisVoice.speechVoices().map(VoiceOption.init),
            languageCode: AVSpeechSynthesisVoice.currentLanguageCode()
        )
    }

    func voiceName(for identifier: String?) -> String {
        guard let identifier, let voice = voices.first(where: { $0.id == identifier }) else {
            return "System default"
        }
        return voice.name
    }

    /// Asks permission to use the Personal Voice the user recorded in iOS Settings
    /// (Accessibility → Personal Voice), then refreshes the voice list.
    func requestPersonalVoice() {
        AVSpeechSynthesizer.requestPersonalVoiceAuthorization { status in
            Task { @MainActor [weak self] in
                self?.personalVoiceStatus = status
                self?.reloadVoices()
            }
        }
    }

    /// Speed shown to people as a multiple of normal speed, e.g. "1.2×".
    nonisolated static func rateLabel(_ rate: Float) -> String {
        String(format: "%.1f×", rate / AVSpeechUtteranceDefaultSpeechRate)
    }
}
