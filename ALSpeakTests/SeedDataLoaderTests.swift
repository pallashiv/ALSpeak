import Foundation
import SwiftData
import Testing
@testable import ALSpeak

@MainActor
struct SeedDataLoaderTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws {
        container = try AppSchema.makeContainer(inMemory: true)
    }

    // MARK: Bundled library

    @Test func bundledLibraryDecodesWithExpectedEnvironments() throws {
        let library = try SeedDataLoader.loadBundledLibrary()
        #expect(library.version >= 1)
        #expect(library.environments.map(\.name) == [
            "Home", "Doctor", "Restaurant", "Out & About", "Family & Friends", "Emergency",
        ])
    }

    @Test func bundledLibraryHasNoEmptyCategoriesOrPhrases() throws {
        let library = try SeedDataLoader.loadBundledLibrary()
        for environment in library.environments {
            #expect(!environment.categories.isEmpty, "\(environment.name) has no categories")
            for category in environment.categories {
                #expect(!category.phrases.isEmpty, "\(environment.name)/\(category.name) is empty")
                for phrase in category.phrases {
                    #expect(!phrase.text.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    @Test func bundledLibraryHasExactlyOneEmergencyEnvironment() throws {
        let library = try SeedDataLoader.loadBundledLibrary()
        #expect(library.environments.filter { $0.isEmergency == true }.count == 1)
    }

    @Test func bundledLibraryTokensAreAllDeclared() throws {
        // Every {token} used by a seed phrase should have an entry in `tokens`, so the
        // settings screen can offer a field for it.
        let library = try SeedDataLoader.loadBundledLibrary()
        let used = library.environments
            .flatMap(\.categories)
            .flatMap(\.phrases)
            .flatMap { TokenResolver.tokenNames(in: $0.text) }
        for token in Set(used) {
            #expect(library.tokens.keys.contains(token), "Token {\(token)} is not declared")
        }
    }

    @Test func bundledLibraryIncludesRequiredQuickResponses() throws {
        let library = try SeedDataLoader.loadBundledLibrary()
        for reply in ["Yes", "No", "Maybe", "Thank you"] {
            #expect(library.quickResponses.contains(reply))
        }
    }

    // MARK: Decoding

    @Test func phraseDecodesFromStringOrObject() throws {
        let json = #"""
        ["Plain", {"text": "Flagged", "showEverywhere": true, "isFavorite": true}, {"text": "Bare object"}]
        """#
        let phrases = try JSONDecoder().decode([SeedPhrase].self, from: Data(json.utf8))
        #expect(phrases == [
            SeedPhrase(text: "Plain"),
            SeedPhrase(text: "Flagged", showEverywhere: true, isFavorite: true),
            SeedPhrase(text: "Bare object"),
        ])
    }

    @Test func malformedLibraryThrows() {
        #expect(throws: (any Error).self) {
            try SeedDataLoader.decode(Data(#"{"version": 1}"#.utf8))
        }
    }

    // MARK: Seeding

    @Test func seedingInsertsEntireLibrary() throws {
        let library = try SeedDataLoader.loadBundledLibrary()
        let didSeed = try SeedDataLoader.seedIfNeeded(context: context) { library }
        #expect(didSeed)

        let expectedCategories = library.environments.flatMap(\.categories)
        let expectedPhrases = expectedCategories.flatMap(\.phrases)
        #expect(try context.fetchCount(FetchDescriptor<SpeakEnvironment>()) == library.environments.count)
        #expect(try context.fetchCount(FetchDescriptor<PhraseCategory>()) == expectedCategories.count)
        #expect(try context.fetchCount(FetchDescriptor<Phrase>()) == expectedPhrases.count)
    }

    @Test func seedingIsIdempotent() throws {
        #expect(try SeedDataLoader.seedIfNeeded(context: context))
        let phraseCount = try context.fetchCount(FetchDescriptor<Phrase>())

        #expect(try SeedDataLoader.seedIfNeeded(context: context) == false)
        #expect(try context.fetchCount(FetchDescriptor<Phrase>()) == phraseCount)
        #expect(try context.fetchCount(FetchDescriptor<UserSettings>()) == 1)
    }

    @Test func seedingDoesNotRestoreEnvironmentsTheUserDeleted() throws {
        try SeedDataLoader.seedIfNeeded(context: context)
        try context.delete(model: SpeakEnvironment.self)
        try context.save()

        #expect(try SeedDataLoader.seedIfNeeded(context: context) == false)
        #expect(try context.fetchCount(FetchDescriptor<SpeakEnvironment>()) == 0)
    }

    @Test func seedingPreservesOrderAndRelationships() throws {
        try SeedDataLoader.seedIfNeeded(context: context)
        let environments = try context.fetch(
            FetchDescriptor<SpeakEnvironment>(sortBy: [SortDescriptor(\.sortOrder)])
        )
        #expect(environments.first?.name == "Home")

        let restaurant = try #require(environments.first { $0.name == "Restaurant" })
        #expect(restaurant.sortedCategories.map(\.name) == ["Ordering", "Needs", "Questions", "Payment"])
        let ordering = try #require(restaurant.sortedCategories.first)
        #expect(ordering.sortedPhrases.first?.text == "I'd like to order now")
        #expect(ordering.sortedPhrases.first?.environment === restaurant)
    }

    @Test func seedingAppliesPhraseFlags() throws {
        try SeedDataLoader.seedIfNeeded(context: context)
        let everywhere = try context.fetch(FetchDescriptor<Phrase>(predicate: #Predicate { $0.showEverywhere }))
        #expect(everywhere.contains { $0.text == "My name is {name}" })
        #expect(everywhere.allSatisfy { !$0.isUserCreated })

        let favorites = try context.fetch(FetchDescriptor<Phrase>(predicate: #Predicate { $0.isFavorite }))
        #expect(favorites.map(\.text) == ["I love you"])
    }

    @Test func seedingCreatesSettingsFromLibrary() throws {
        let library = try SeedDataLoader.loadBundledLibrary()
        try SeedDataLoader.seedIfNeeded(context: context) { library }

        let settings = UserSettings.current(in: context)
        #expect(settings.emergencyPhrase == library.emergencyPhrase)
        #expect(settings.quickResponses == library.quickResponses)
        #expect(settings.tokens == library.tokens)
        #expect(settings.seedVersion == library.version)
    }
}
