import Foundation
import SwiftData

/// A place or situation the user is in (Home, Restaurant, Doctor…).
///
/// Named `SpeakEnvironment` rather than `Environment` so it never collides with
/// SwiftUI's `@Environment` property wrapper.
@Model
final class SpeakEnvironment {
    var id: UUID = UUID()
    var name: String = ""
    /// SF Symbol shown on the environment card.
    var symbolName: String = "square.grid.2x2.fill"
    /// Key into the app's color palette (e.g. "blue", "red") rather than a raw color,
    /// so themes such as high contrast can remap it.
    var colorKey: String = "blue"
    var sortOrder: Int = 0
    /// Hidden environments stay in the database but are not shown on the home screen.
    var isHidden: Bool = false
    /// The Emergency/Caregiver environment gets special styling and placement.
    var isEmergency: Bool = false

    /// Deleting an environment deletes its categories (and, through them, their phrases).
    @Relationship(deleteRule: .cascade, inverse: \PhraseCategory.environment)
    var categories: [PhraseCategory] = []

    init(
        name: String,
        symbolName: String = "square.grid.2x2.fill",
        colorKey: String = "blue",
        sortOrder: Int = 0,
        isHidden: Bool = false,
        isEmergency: Bool = false
    ) {
        self.name = name
        self.symbolName = symbolName
        self.colorKey = colorKey
        self.sortOrder = sortOrder
        self.isHidden = isHidden
        self.isEmergency = isEmergency
    }

    /// Categories in the user's chosen order.
    var sortedCategories: [PhraseCategory] {
        categories.sorted { $0.sortOrder < $1.sortOrder }
    }

    /// Every phrase in this environment, in display order.
    var allPhrases: [Phrase] {
        sortedCategories.flatMap(\.sortedPhrases)
    }
}
