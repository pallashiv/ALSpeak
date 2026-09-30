import Foundation
import SwiftData
import Testing
@testable import ALSpeak

@MainActor
struct ModelTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws {
        container = try AppSchema.makeContainer(inMemory: true)
    }

    /// Builds one environment with two categories (inserted out of order) and three phrases.
    @discardableResult
    private func makeSampleEnvironment() -> SpeakEnvironment {
        let environment = SpeakEnvironment(name: "Test", sortOrder: 0)
        context.insert(environment)

        let second = PhraseCategory(name: "Second", sortOrder: 1)
        let first = PhraseCategory(name: "First", sortOrder: 0)
        for category in [second, first] {
            context.insert(category)
            category.environment = environment
        }

        for (index, text) in ["B", "A"].enumerated().reversed() {
            let phrase = Phrase(text: text, sortOrder: index)
            context.insert(phrase)
            phrase.category = first
        }
        let other = Phrase(text: "C")
        context.insert(other)
        other.category = second
        return environment
    }

    @Test func categoriesAndPhrasesSortBySortOrder() {
        let environment = makeSampleEnvironment()
        #expect(environment.sortedCategories.map(\.name) == ["First", "Second"])
        #expect(environment.allPhrases.map(\.text) == ["B", "A", "C"])
    }

    @Test func relationshipsAreBidirectional() throws {
        let environment = makeSampleEnvironment()
        try context.save()
        #expect(environment.categories.count == 2)
        let phrase = try #require(environment.allPhrases.first)
        #expect(phrase.environment === environment)
    }

    @Test func deletingEnvironmentCascadesToCategoriesAndPhrases() throws {
        let environment = makeSampleEnvironment()
        try context.save()

        context.delete(environment)
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<SpeakEnvironment>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<PhraseCategory>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Phrase>()) == 0)
    }

    @Test func deletingCategoryKeepsOtherCategories() throws {
        let environment = makeSampleEnvironment()
        try context.save()

        let first = try #require(environment.sortedCategories.first)
        context.delete(first)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<Phrase>()).map(\.text) == ["C"])
        #expect(environment.sortedCategories.map(\.name) == ["Second"])
    }

    @Test func markUsedUpdatesUsageData() {
        let phrase = Phrase(text: "Hello")
        context.insert(phrase)
        let date = Date(timeIntervalSince1970: 1_000)

        phrase.markUsed(at: date)
        phrase.markUsed(at: date.addingTimeInterval(60))

        #expect(phrase.useCount == 2)
        #expect(phrase.lastUsedAt == date.addingTimeInterval(60))
    }

    @Test func settingsCurrentCreatesExactlyOneRecord() throws {
        let a = UserSettings.current(in: context)
        let b = UserSettings.current(in: context)
        #expect(a === b)
        #expect(try context.fetchCount(FetchDescriptor<UserSettings>()) == 1)
    }

    @Test func settingsEnumsRoundTripAndFallBack() {
        let settings = UserSettings()
        settings.touchMode = .dwell
        settings.theme = .highContrast
        #expect(settings.touchModeRaw == "dwell")
        #expect(settings.theme == .highContrast)

        settings.touchModeRaw = "garbage"
        settings.themeRaw = "garbage"
        #expect(settings.touchMode == .tap)
        #expect(settings.theme == .standard)
    }

    @Test func settingsCollectionsPersist() throws {
        let settings = UserSettings.current(in: context)
        settings.tokens = ["name": "Sam", "favoriteDrink": "iced tea"]
        settings.quickResponses = ["Yes", "No"]
        try context.save()

        // Read back through a fresh context to make sure values really hit the store.
        let fresh = ModelContext(container)
        let stored = try #require(try fresh.fetch(FetchDescriptor<UserSettings>()).first)
        #expect(stored.tokens == ["name": "Sam", "favoriteDrink": "iced tea"])
        #expect(stored.quickResponses == ["Yes", "No"])
    }
}
