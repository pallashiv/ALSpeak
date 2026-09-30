import Foundation
import SwiftData

/// A group of phrases inside an environment (e.g. Restaurant → "Ordering").
@Model
final class PhraseCategory {
    var id: UUID = UUID()
    var name: String = ""
    var sortOrder: Int = 0

    var environment: SpeakEnvironment?

    /// Deleting a category deletes its phrases.
    @Relationship(deleteRule: .cascade, inverse: \Phrase.category)
    var phrases: [Phrase] = []

    init(name: String, sortOrder: Int = 0) {
        self.name = name
        self.sortOrder = sortOrder
    }

    /// Phrases in the user's chosen order.
    var sortedPhrases: [Phrase] {
        phrases.sorted { $0.sortOrder < $1.sortOrder }
    }
}
