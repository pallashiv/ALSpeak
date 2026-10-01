import Foundation
import SwiftData

/// How a phrase button decides it has been deliberately selected.
/// Tolerant input matters: tremor or a dragging finger must not trigger speech.
enum TouchMode: String, CaseIterable, Codable, Identifiable {
    /// A normal tap; drags and scrolls are ignored.
    case tap
    /// Press and hold for `UserSettings.dwellDuration` before the phrase is spoken.
    case hold
    /// Selection by resting on a button (for head/eye pointers); uses `dwellDuration`.
    case dwell

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .tap: "Tap"
        case .hold: "Press and hold"
        case .dwell: "Dwell (rest to select)"
        }
    }
}

/// Visual theme for the whole app.
enum AppTheme: String, CaseIterable, Codable, Identifiable {
    case standard
    case highContrast

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .standard: "Standard"
        case .highContrast: "High contrast"
        }
    }
}

/// App-wide preferences. Exactly one record exists; use `UserSettings.current(in:)`.
@Model
final class UserSettings {
    // MARK: Voice

    /// `AVSpeechSynthesisVoice.identifier`; nil means the system default for the locale.
    var voiceIdentifier: String?
    /// 0...1, same scale as `AVSpeechUtterance.rate` (0.5 is the system default).
    var speechRate: Float = 0.5
    /// 0.5...2.0, same scale as `AVSpeechUtterance.pitchMultiplier`.
    var pitch: Float = 1.0
    /// 0...1, same scale as `AVSpeechUtterance.volume`.
    var volume: Float = 1.0

    // MARK: Emergency

    var emergencyPhrase: String = "I need help, please come here now."
    /// How many times the emergency phrase is repeated per press.
    var emergencyRepeatCount: Int = 2
    /// When true the Emergency button must be held for a moment, so a tremor or a brush
    /// of the hand doesn't sound the alarm. VoiceOver / Switch Control activate it directly.
    var emergencyRequiresHold: Bool = true

    // MARK: Personalization

    /// Values for phrase tokens, e.g. ["name": "Sam", "favoriteDrink": "iced tea"].
    var tokens: [String: String] = [:]
    /// Replies shown in the Quick Respond bar, in order.
    var quickResponses: [String] = []
    /// Most recent type-to-speak texts, newest first (capped, see `TypeToSpeakViewModel`).
    var recentTypedTexts: [String] = []

    // MARK: Touch & display

    var touchModeRaw: String = TouchMode.tap.rawValue
    /// Seconds a finger/pointer must stay on a button in hold or dwell mode.
    var dwellDuration: Double = 0.8
    var themeRaw: String = AppTheme.standard.rawValue

    // MARK: Bookkeeping

    /// Version of the bundled seed library that was loaded. 0 means never seeded.
    var seedVersion: Int = 0

    init() {}

    var touchMode: TouchMode {
        get { TouchMode(rawValue: touchModeRaw) ?? .tap }
        set { touchModeRaw = newValue.rawValue }
    }

    var theme: AppTheme {
        get { AppTheme(rawValue: themeRaw) ?? .standard }
        set { themeRaw = newValue.rawValue }
    }

    /// Returns the single settings record, creating one if it doesn't exist yet.
    @MainActor
    static func current(in context: ModelContext) -> UserSettings {
        if let existing = try? context.fetch(FetchDescriptor<UserSettings>()).first {
            return existing
        }
        let settings = UserSettings()
        context.insert(settings)
        return settings
    }
}
