import Foundation
import SwiftData
import Testing
@testable import ALSpeak

@MainActor
struct PhraseBoardViewModelTests {
    let container: ModelContainer
    let viewModel = PhraseBoardViewModel()
    var context: ModelContext { container.mainContext }

    init() throws {
        container = try AppSchema.makeContainer(inMemory: true)
    }

    private func makeEnvironment(_ name: String, categories: [(String, [Phrase])]) -> SpeakEnvironment {
        let environment = SpeakEnvironment(name: name)
        context.insert(environment)
        for (catIndex, (catName, phrases)) in categories.enumerated() {
            let category = PhraseCategory(name: catName, sortOrder: catIndex)
            context.insert(category)
            category.environment = environment
            for (index, phrase) in phrases.enumerated() {
                phrase.sortOrder = index
                context.insert(phrase)
                phrase.category = category
            }
        }
        return environment
    }

    @Test func allShowsPinnedThenCategories() {
        let favorite = Phrase(text: "Fav", isFavorite: true)
        let env = makeEnvironment("E", categories: [("One", [Phrase(text: "a"), favorite]), ("Two", [Phrase(text: "b")])])

        let sections = viewModel.sections(for: env, everywhere: [])
        #expect(sections.map(\.title) == ["Pinned", "One", "Two"])
        #expect(sections[0].phrases.map(\.text) == ["Fav"])
        #expect(sections[1].phrases.map(\.text) == ["a", "Fav"])
    }

    @Test func pinnedIncludesEverywherePhrasesFromOtherEnvironmentsWithoutDuplicates() {
        let local = Phrase(text: "Local", isFavorite: true, showEverywhere: true)
        let env = makeEnvironment("E", categories: [("One", [local])])
        let foreign = Phrase(text: "Foreign", showEverywhere: true)
        _ = makeEnvironment("Other", categories: [("X", [foreign])])

        let pinned = viewModel.pinnedPhrases(in: env, everywhere: [local, foreign])
        #expect(pinned.map(\.text) == ["Local", "Foreign"])
    }

    @Test func noPinnedSectionWhenNothingIsPinned() {
        let env = makeEnvironment("E", categories: [("One", [Phrase(text: "a")])])
        #expect(viewModel.sections(for: env, everywhere: []).map(\.title) == ["One"])
    }

    @Test func emptyCategoriesAreHiddenInAll() {
        let env = makeEnvironment("E", categories: [("Empty", []), ("One", [Phrase(text: "a")])])
        #expect(viewModel.sections(for: env, everywhere: []).map(\.title) == ["One"])
    }

    @Test func editModeIncludesEmptyCategoriesAndExposesCategory() {
        let env = makeEnvironment("E", categories: [("Empty", []), ("One", [Phrase(text: "a")])])
        let sections = viewModel.sections(for: env, everywhere: [], includeEmpty: true)
        #expect(sections.map(\.title) == ["Empty", "One"])
        #expect(sections.allSatisfy { $0.category != nil })
    }

    @Test func pinnedSectionHasNoCategory() {
        let env = makeEnvironment("E", categories: [("One", [Phrase(text: "a", isFavorite: true)])])
        let pinned = viewModel.sections(for: env, everywhere: []).first
        #expect(pinned?.id == PhraseBoardViewModel.pinnedSectionID)
        #expect(pinned?.category == nil)
    }

    @Test func categoryFilterShowsOnlyThatCategory() throws {
        let env = makeEnvironment("E", categories: [("One", [Phrase(text: "a")]), ("Two", [Phrase(text: "b")])])
        let two = try #require(env.sortedCategories.last)

        viewModel.filter = .category(two.id)
        let sections = viewModel.sections(for: env, everywhere: [])
        #expect(sections.map(\.title) == ["Two"])
        #expect(sections[0].phrases.map(\.text) == ["b"])
    }

    @Test func staleCategoryFilterFallsBackToAll() {
        let env = makeEnvironment("E", categories: [("One", [Phrase(text: "a")])])
        viewModel.filter = .category(UUID())
        #expect(viewModel.sections(for: env, everywhere: []).map(\.title) == ["One"])
    }
}

@MainActor
struct EnvironmentPickerViewModelTests {
    let container: ModelContainer
    let viewModel = EnvironmentPickerViewModel()
    var context: ModelContext { container.mainContext }

    init() throws {
        container = try AppSchema.makeContainer(inMemory: true)
    }

    @Test func hiddenEnvironmentsAreExcludedAndOrderIsRespected() {
        let b = SpeakEnvironment(name: "B", sortOrder: 1)
        let a = SpeakEnvironment(name: "A", sortOrder: 0)
        let hidden = SpeakEnvironment(name: "H", sortOrder: 2, isHidden: true)
        [b, a, hidden].forEach(context.insert)

        #expect(viewModel.visibleEnvironments([b, a, hidden]).map(\.name) == ["A", "B"])
    }

    @Test func homeFavoritesHaveStableBoardOrderAndSkipHiddenEnvironments() throws {
        try SeedDataLoader.seedIfNeeded(context: context)
        let all = try context.fetch(FetchDescriptor<Phrase>())
        let home = try #require(all.first { $0.text == "I'm hungry" })
        let restaurant = try #require(all.first { $0.text == "I'd like to order now" })
        let family = try #require(all.first { $0.text == "I love you" })
        [home, restaurant].forEach { $0.isFavorite = true }

        // Using a phrase must not move it.
        restaurant.markUsed()
        let favorites = [family, restaurant, home]
        #expect(viewModel.homeFavorites(favorites).map(\.text) == ["I'm hungry", "I'd like to order now", "I love you"])

        family.environment?.isHidden = true
        #expect(viewModel.homeFavorites(favorites).map(\.text) == ["I'm hungry", "I'd like to order now"])
    }
}
