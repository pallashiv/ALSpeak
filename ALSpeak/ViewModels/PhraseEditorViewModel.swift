import Foundation
import Observation

/// Draft state for adding or editing one phrase. Nothing is written until `save`.
@MainActor
@Observable
final class PhraseEditorViewModel: Identifiable {
    let id = UUID()
    /// nil when creating a new phrase.
    let phrase: Phrase?
    /// Categories the phrase can live in (all categories of its environment).
    let categories: [PhraseCategory]

    var text: String
    var categoryID: UUID?
    var isFavorite: Bool
    var showEverywhere: Bool

    /// Edit an existing phrase.
    init(phrase: Phrase) {
        self.phrase = phrase
        self.categories = phrase.environment?.sortedCategories ?? phrase.category.map { [$0] } ?? []
        self.text = phrase.text
        self.categoryID = phrase.category?.id
        self.isFavorite = phrase.isFavorite
        self.showEverywhere = phrase.showEverywhere
    }

    /// Create a new phrase in `category`, optionally prefilled (e.g. from type-to-speak).
    init(newIn category: PhraseCategory, text: String = "") {
        self.phrase = nil
        self.categories = category.environment?.sortedCategories ?? [category]
        self.text = text
        self.categoryID = category.id
        self.isFavorite = false
        self.showEverywhere = false
    }

    var isNew: Bool { phrase == nil }
    var trimmedText: String { text.trimmed }
    var selectedCategory: PhraseCategory? { categories.first { $0.id == categoryID } }
    var canSave: Bool { !trimmedText.isEmpty && selectedCategory != nil }

    /// Appends a `{token}` placeholder, adding a separating space when needed.
    func insertToken(_ name: String) {
        let needsSpace = !(text.isEmpty || text.hasSuffix(" ") || text.hasSuffix("\n"))
        text += (needsSpace ? " " : "") + "{\(name)}"
    }

    /// Writes the draft. Returns the saved phrase, or nil if the draft isn't valid.
    @discardableResult
    func save(using editor: PhraseLibraryEditor) -> Phrase? {
        guard canSave, let category = selectedCategory else { return nil }
        if let phrase {
            editor.update(phrase, text: trimmedText, category: category,
                          isFavorite: isFavorite, showEverywhere: showEverywhere)
            return phrase
        }
        return editor.addPhrase(text: trimmedText, to: category,
                                isFavorite: isFavorite, showEverywhere: showEverywhere)
    }

    func delete(using editor: PhraseLibraryEditor) {
        guard let phrase else { return }
        editor.delete(phrase)
    }
}
