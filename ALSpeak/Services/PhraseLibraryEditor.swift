import Foundation
import SwiftData
import os

/// Every create / update / reorder / delete on the phrase library goes through here, so
/// sort orders, flags and saves are handled the same way no matter which screen edits.
@MainActor
struct PhraseLibraryEditor {
    let context: ModelContext

    /// Name of the category automatically created inside a new environment, so it can
    /// hold phrases immediately.
    static let defaultCategoryName = "General"

    // MARK: Environments

    @discardableResult
    func addEnvironment(name: String, symbolName: String, colorKey: String) -> SpeakEnvironment {
        let existing = (try? context.fetch(FetchDescriptor<SpeakEnvironment>())) ?? []
        let environment = SpeakEnvironment(
            name: name.trimmed,
            symbolName: symbolName,
            colorKey: colorKey,
            sortOrder: Self.nextSortOrder(after: existing.map(\.sortOrder))
        )
        context.insert(environment)
        addCategory(named: Self.defaultCategoryName, to: environment)
        save()
        return environment
    }

    func update(_ environment: SpeakEnvironment, name: String, symbolName: String, colorKey: String) {
        environment.name = name.trimmed
        environment.symbolName = symbolName
        environment.colorKey = colorKey
        save()
    }

    func setHidden(_ environment: SpeakEnvironment, _ isHidden: Bool) {
        environment.isHidden = isHidden
        save()
    }

    /// Applies a List `onMove` to environments shown in `ordered` order.
    func moveEnvironments(_ ordered: [SpeakEnvironment], from source: IndexSet, to destination: Int) {
        Reorder.moved(ordered, from: source, to: destination)
            .enumerated()
            .forEach { $1.sortOrder = $0 }
        save()
    }

    /// Deletes the environment with all its categories and phrases.
    func delete(_ environment: SpeakEnvironment) {
        context.delete(environment)
        save()
    }

    // MARK: Categories

    @discardableResult
    func addCategory(named name: String, to environment: SpeakEnvironment) -> PhraseCategory {
        let category = PhraseCategory(
            name: name.trimmed,
            sortOrder: Self.nextSortOrder(after: environment.categories.map(\.sortOrder))
        )
        context.insert(category)
        category.environment = environment
        save()
        return category
    }

    func rename(_ category: PhraseCategory, to name: String) {
        category.name = name.trimmed
        save()
    }

    func moveCategories(in environment: SpeakEnvironment, from source: IndexSet, to destination: Int) {
        Reorder.moved(environment.sortedCategories, from: source, to: destination)
            .enumerated()
            .forEach { $1.sortOrder = $0 }
        save()
    }

    /// Deletes the category and all of its phrases.
    func delete(_ category: PhraseCategory) {
        context.delete(category)
        save()
    }

    // MARK: Phrases

    @discardableResult
    func addPhrase(
        text: String,
        to category: PhraseCategory,
        isFavorite: Bool = false,
        showEverywhere: Bool = false
    ) -> Phrase {
        let phrase = Phrase(
            text: text.trimmed,
            sortOrder: Self.nextSortOrder(after: category.phrases.map(\.sortOrder)),
            isFavorite: isFavorite,
            showEverywhere: showEverywhere,
            isUserCreated: true
        )
        context.insert(phrase)
        phrase.category = category
        save()
        return phrase
    }

    /// Updates a phrase. Moving it to a different category puts it at the end of that category.
    func update(
        _ phrase: Phrase,
        text: String,
        category: PhraseCategory,
        isFavorite: Bool,
        showEverywhere: Bool
    ) {
        phrase.text = text.trimmed
        phrase.isFavorite = isFavorite
        phrase.showEverywhere = showEverywhere
        if phrase.category?.id != category.id {
            phrase.sortOrder = Self.nextSortOrder(after: category.phrases.map(\.sortOrder))
            phrase.category = category
        }
        save()
    }

    func movePhrases(in category: PhraseCategory, from source: IndexSet, to destination: Int) {
        Reorder.moved(category.sortedPhrases, from: source, to: destination)
            .enumerated()
            .forEach { $1.sortOrder = $0 }
        save()
    }

    func setFavorite(_ phrase: Phrase, _ isFavorite: Bool) {
        phrase.isFavorite = isFavorite
        save()
    }

    func setShowEverywhere(_ phrase: Phrase, _ showEverywhere: Bool) {
        phrase.showEverywhere = showEverywhere
        save()
    }

    func delete(_ phrase: Phrase) {
        context.delete(phrase)
        save()
    }

    // MARK: Helpers

    func save() {
        do {
            try context.save()
        } catch {
            Logger.app.error("Saving library edit failed: \(error.localizedDescription)")
        }
    }

    private static func nextSortOrder(after orders: [Int]) -> Int {
        (orders.max() ?? -1) + 1
    }
}

/// Array reordering with the same semantics as SwiftUI's `onMove(perform:)`.
enum Reorder {
    static func moved<T>(_ items: [T], from source: IndexSet, to destination: Int) -> [T] {
        var result = items
        let moving = source.map { items[$0] }
        for index in source.reversed() {
            result.remove(at: index)
        }
        let insertionIndex = destination - source.filter { $0 < destination }.count
        result.insert(contentsOf: moving, at: insertionIndex)
        return result
    }
}

extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
