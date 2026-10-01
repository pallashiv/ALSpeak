import Foundation
import SwiftData
import Testing
@testable import ALSpeak

@MainActor
struct PhraseLibraryEditorTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }
    var editor: PhraseLibraryEditor { PhraseLibraryEditor(context: context) }

    init() throws {
        container = try AppSchema.makeContainer(inMemory: true)
    }

    private func environments() throws -> [SpeakEnvironment] {
        try context.fetch(FetchDescriptor<SpeakEnvironment>(sortBy: [SortDescriptor(\.sortOrder)]))
    }

    // MARK: Reorder helper

    @Test(arguments: [
        (IndexSet([0]), 3, ["b", "c", "a", "d"]),   // move first down
        (IndexSet([3]), 0, ["d", "a", "b", "c"]),   // move last to top
        (IndexSet([1]), 4, ["a", "c", "d", "b"]),   // move to end
        (IndexSet([0, 2]), 4, ["b", "d", "a", "c"]), // move several
        (IndexSet([2]), 2, ["a", "b", "c", "d"]),   // no-op
    ])
    func reorderMatchesOnMoveSemantics(source: IndexSet, destination: Int, expected: [String]) {
        #expect(Reorder.moved(["a", "b", "c", "d"], from: source, to: destination) == expected)
    }

    // MARK: Environments

    @Test func addedEnvironmentGoesLastWithADefaultCategory() throws {
        editor.addEnvironment(name: "Home", symbolName: "house.fill", colorKey: "blue")
        let church = editor.addEnvironment(name: "  Church  ", symbolName: "building.columns.fill", colorKey: "purple")

        #expect(church.name == "Church")
        #expect(try environments().map(\.name) == ["Home", "Church"])
        #expect(church.sortedCategories.map(\.name) == [PhraseLibraryEditor.defaultCategoryName])
    }

    @Test func updateChangesNameIconAndColor() {
        let env = editor.addEnvironment(name: "Car", symbolName: "car.fill", colorKey: "blue")
        editor.update(env, name: "Van ", symbolName: "bus.fill", colorKey: "green")
        #expect(env.name == "Van")
        #expect(env.symbolName == "bus.fill")
        #expect(env.colorKey == "green")
    }

    @Test func moveEnvironmentsRenumbersSortOrder() throws {
        for name in ["A", "B", "C"] {
            editor.addEnvironment(name: name, symbolName: "house.fill", colorKey: "blue")
        }
        editor.moveEnvironments(try environments(), from: IndexSet([2]), to: 0)
        #expect(try environments().map(\.name) == ["C", "A", "B"])
        #expect(try environments().map(\.sortOrder) == [0, 1, 2])
    }

    @Test func hideAndShowEnvironment() {
        let env = editor.addEnvironment(name: "A", symbolName: "house.fill", colorKey: "blue")
        editor.setHidden(env, true)
        #expect(env.isHidden)
        editor.setHidden(env, false)
        #expect(!env.isHidden)
    }

    @Test func deletingEnvironmentRemovesItsPhrases() throws {
        let env = editor.addEnvironment(name: "A", symbolName: "house.fill", colorKey: "blue")
        editor.addPhrase(text: "Hello", to: env.sortedCategories[0])

        editor.delete(env)
        #expect(try context.fetchCount(FetchDescriptor<SpeakEnvironment>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Phrase>()) == 0)
    }

    // MARK: Categories

    @Test func categoriesAddRenameMoveDelete() throws {
        let env = editor.addEnvironment(name: "A", symbolName: "house.fill", colorKey: "blue")
        let drinks = editor.addCategory(named: "Drinks", to: env)
        editor.addCategory(named: "Snacks", to: env)
        #expect(env.sortedCategories.map(\.name) == ["General", "Drinks", "Snacks"])

        editor.rename(drinks, to: " Beverages ")
        editor.moveCategories(in: env, from: IndexSet([2]), to: 0)
        #expect(env.sortedCategories.map(\.name) == ["Snacks", "General", "Beverages"])

        editor.addPhrase(text: "Water", to: drinks)
        editor.delete(drinks)
        #expect(env.sortedCategories.map(\.name) == ["Snacks", "General"])
        #expect(try context.fetchCount(FetchDescriptor<Phrase>()) == 0)
    }

    // MARK: Phrases

    @Test func addedPhraseIsUserCreatedAndGoesLast() {
        let env = editor.addEnvironment(name: "A", symbolName: "house.fill", colorKey: "blue")
        let category = env.sortedCategories[0]
        editor.addPhrase(text: "First", to: category)
        let second = editor.addPhrase(text: " Second ", to: category, isFavorite: true, showEverywhere: true)

        #expect(category.sortedPhrases.map(\.text) == ["First", "Second"])
        #expect(second.isUserCreated)
        #expect(second.isFavorite)
        #expect(second.showEverywhere)
    }

    @Test func updatingPhraseCategoryMovesItToTheEnd() {
        let env = editor.addEnvironment(name: "A", symbolName: "house.fill", colorKey: "blue")
        let general = env.sortedCategories[0]
        let other = editor.addCategory(named: "Other", to: env)
        editor.addPhrase(text: "Existing", to: other)
        let phrase = editor.addPhrase(text: "Movable", to: general)

        editor.update(phrase, text: "Moved", category: other, isFavorite: true, showEverywhere: false)

        #expect(general.phrases.isEmpty)
        #expect(other.sortedPhrases.map(\.text) == ["Existing", "Moved"])
        #expect(phrase.isFavorite)
    }

    @Test func updatingPhraseInSameCategoryKeepsPosition() {
        let env = editor.addEnvironment(name: "A", symbolName: "house.fill", colorKey: "blue")
        let category = env.sortedCategories[0]
        let first = editor.addPhrase(text: "First", to: category)
        editor.addPhrase(text: "Second", to: category)

        editor.update(first, text: "First edited", category: category, isFavorite: false, showEverywhere: false)
        #expect(category.sortedPhrases.map(\.text) == ["First edited", "Second"])
    }

    @Test func movePhrasesAndDelete() {
        let env = editor.addEnvironment(name: "A", symbolName: "house.fill", colorKey: "blue")
        let category = env.sortedCategories[0]
        for text in ["a", "b", "c"] { editor.addPhrase(text: text, to: category) }

        editor.movePhrases(in: category, from: IndexSet([0]), to: 3)
        #expect(category.sortedPhrases.map(\.text) == ["b", "c", "a"])

        editor.delete(category.sortedPhrases[1])
        #expect(category.sortedPhrases.map(\.text) == ["b", "a"])
    }

    @Test func favoriteAndEverywhereFlags() {
        let env = editor.addEnvironment(name: "A", symbolName: "house.fill", colorKey: "blue")
        let phrase = editor.addPhrase(text: "Hi", to: env.sortedCategories[0])
        editor.setFavorite(phrase, true)
        editor.setShowEverywhere(phrase, true)
        #expect(phrase.isFavorite && phrase.showEverywhere)
    }
}
