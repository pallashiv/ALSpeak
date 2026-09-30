import Foundation
import SwiftData

/// A single speakable phrase.
///
/// `text` may contain tokens such as `{name}` or `{favoriteDrink}`; these are filled in
/// from `UserSettings.tokens` at speak time by `TokenResolver`.
@Model
final class Phrase {
    var id: UUID = UUID()
    var text: String = ""
    var sortOrder: Int = 0
    var isFavorite: Bool = false
    /// When true the phrase appears on every environment's board, not just its own.
    var showEverywhere: Bool = false
    /// Distinguishes phrases the user/caregiver wrote from the bundled library.
    var isUserCreated: Bool = false

    // Usage data, kept for "recent" lists now and phrase learning / suggestions later.
    var lastUsedAt: Date?
    var useCount: Int = 0

    var category: PhraseCategory?

    init(
        text: String,
        sortOrder: Int = 0,
        isFavorite: Bool = false,
        showEverywhere: Bool = false,
        isUserCreated: Bool = false
    ) {
        self.text = text
        self.sortOrder = sortOrder
        self.isFavorite = isFavorite
        self.showEverywhere = showEverywhere
        self.isUserCreated = isUserCreated
    }

    /// The environment this phrase belongs to, via its category.
    var environment: SpeakEnvironment? {
        category?.environment
    }

    /// Records that the phrase was just spoken.
    func markUsed(at date: Date = .now) {
        lastUsedAt = date
        useCount += 1
    }
}
