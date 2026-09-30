import Foundation
import SwiftData

// MARK: - Seed file format (SeedPhrases.json)

/// Top-level shape of the bundled seed library.
struct SeedLibrary: Decodable {
    /// Bump when the bundled library changes; stored in `UserSettings.seedVersion`.
    let version: Int
    let emergencyPhrase: String
    let quickResponses: [String]
    let tokens: [String: String]
    let environments: [SeedEnvironment]
}

struct SeedEnvironment: Decodable {
    let name: String
    let symbol: String
    let color: String
    let isEmergency: Bool?
    let categories: [SeedCategory]
}

struct SeedCategory: Decodable {
    let name: String
    let phrases: [SeedPhrase]
}

/// A phrase in the seed file: either a bare string, or an object with flags:
/// `{ "text": "...", "showEverywhere": true, "isFavorite": true }`.
struct SeedPhrase: Decodable, Equatable {
    let text: String
    let showEverywhere: Bool
    let isFavorite: Bool

    private enum CodingKeys: String, CodingKey {
        case text, showEverywhere, isFavorite
    }

    init(text: String, showEverywhere: Bool = false, isFavorite: Bool = false) {
        self.text = text
        self.showEverywhere = showEverywhere
        self.isFavorite = isFavorite
    }

    init(from decoder: Decoder) throws {
        if let single = try? decoder.singleValueContainer(), let text = try? single.decode(String.self) {
            self.init(text: text)
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            text: try container.decode(String.self, forKey: .text),
            showEverywhere: try container.decodeIfPresent(Bool.self, forKey: .showEverywhere) ?? false,
            isFavorite: try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        )
    }
}

// MARK: - Loader

/// Loads the bundled phrase library into SwiftData on first launch.
enum SeedDataLoader {
    enum SeedError: Error {
        case resourceMissing(String)
    }

    static let resourceName = "SeedPhrases"

    /// Reads and decodes `SeedPhrases.json` from the given bundle.
    static func loadBundledLibrary(from bundle: Bundle = .main) throws -> SeedLibrary {
        guard let url = bundle.url(forResource: resourceName, withExtension: "json") else {
            throw SeedError.resourceMissing("\(resourceName).json")
        }
        return try decode(Data(contentsOf: url))
    }

    static func decode(_ data: Data) throws -> SeedLibrary {
        try JSONDecoder().decode(SeedLibrary.self, from: data)
    }

    /// Seeds the store if it has never been seeded.
    ///
    /// "Seeded" is tracked by the existence of a `UserSettings` record rather than by
    /// counting environments, so a user who deletes every environment doesn't get the
    /// defaults back on next launch.
    ///
    /// - Returns: `true` if seeding happened.
    @MainActor
    @discardableResult
    static func seedIfNeeded(
        context: ModelContext,
        library makeLibrary: () throws -> SeedLibrary = { try loadBundledLibrary() }
    ) throws -> Bool {
        let existingSettings = try context.fetchCount(FetchDescriptor<UserSettings>())
        guard existingSettings == 0 else { return false }

        let library = try makeLibrary()
        insert(library, into: context)
        try context.save()
        return true
    }

    /// Inserts every environment, category and phrase from the library, plus a
    /// `UserSettings` record populated with the library's defaults.
    @MainActor
    static func insert(_ library: SeedLibrary, into context: ModelContext) {
        for (envIndex, seedEnv) in library.environments.enumerated() {
            let environment = SpeakEnvironment(
                name: seedEnv.name,
                symbolName: seedEnv.symbol,
                colorKey: seedEnv.color,
                sortOrder: envIndex,
                isEmergency: seedEnv.isEmergency ?? false
            )
            context.insert(environment)

            for (catIndex, seedCat) in seedEnv.categories.enumerated() {
                let category = PhraseCategory(name: seedCat.name, sortOrder: catIndex)
                context.insert(category)
                category.environment = environment

                for (phraseIndex, seedPhrase) in seedCat.phrases.enumerated() {
                    let phrase = Phrase(
                        text: seedPhrase.text,
                        sortOrder: phraseIndex,
                        isFavorite: seedPhrase.isFavorite,
                        showEverywhere: seedPhrase.showEverywhere
                    )
                    context.insert(phrase)
                    phrase.category = category
                }
            }
        }

        let settings = UserSettings()
        settings.emergencyPhrase = library.emergencyPhrase
        settings.quickResponses = library.quickResponses
        settings.tokens = library.tokens
        settings.seedVersion = library.version
        context.insert(settings)
    }
}
