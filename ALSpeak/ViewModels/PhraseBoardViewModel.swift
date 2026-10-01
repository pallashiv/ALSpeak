import Foundation
import Observation

/// A titled block of phrases on the board.
struct PhraseSection: Identifiable {
    let id: String
    let title: String
    let phrases: [Phrase]
    /// The category this section shows; nil for the Favorites section.
    var category: PhraseCategory? = nil
}

/// Decides which phrases the board shows.
///
/// The board shows **one tab at a time** so the screen stays simple: a handful of big
/// buttons, no section headers, little scrolling. Tabs are:
/// 1. **Favorites** — this place's favorites + every "show everywhere" phrase (only if any),
/// 2. each category, in order.
///
/// A board opens on Favorites if the place has favorites of its own, otherwise on its first
/// category, so the most-used phrases are two taps from home: place → phrase.
@MainActor
@Observable
final class PhraseBoardViewModel {
    enum Filter: Hashable {
        /// Every section stacked (kept for callers that want the whole board).
        case all
        case favorites
        case category(UUID)
    }

    struct Tab: Identifiable, Hashable {
        let filter: Filter
        let title: String
        var id: Filter { filter }
    }

    /// The tab the user picked; nil means "the first tab".
    var filter: Filter?

    static let favoritesSectionID = "favorites"
    static let favoritesTitle = "Favorites"

    /// Favorites from this environment, then "show everywhere" phrases from any environment,
    /// without duplicates.
    func pinnedPhrases(in environment: SpeakEnvironment, everywhere: [Phrase]) -> [Phrase] {
        var seen = Set<UUID>()
        let favorites = environment.allPhrases.filter(\.isFavorite)
        let shared = everywhere.sorted { $0.text.localizedCompare($1.text) == .orderedAscending }
        return (favorites + shared).filter { seen.insert($0.id).inserted }
    }

    func tabs(for environment: SpeakEnvironment, everywhere: [Phrase]) -> [Tab] {
        var result: [Tab] = []
        if !pinnedPhrases(in: environment, everywhere: everywhere).isEmpty {
            result.append(Tab(filter: .favorites, title: Self.favoritesTitle))
        }
        result += environment.sortedCategories.map {
            Tab(filter: .category($0.id), title: $0.name.isEmpty ? "Untitled" : $0.name)
        }
        return result
    }

    /// The tab actually shown: the user's pick if it still exists. Otherwise Favorites if
    /// this place has favorites of its own, else its first category — so a place opens on
    /// its own phrases rather than on the general "show everywhere" ones.
    func selectedTab(for environment: SpeakEnvironment, everywhere: [Phrase]) -> Filter? {
        let tabs = tabs(for: environment, everywhere: everywhere)
        if let filter, tabs.contains(where: { $0.filter == filter }) {
            return filter
        }
        if environment.allPhrases.contains(where: \.isFavorite) {
            return .favorites
        }
        return tabs.first { $0.filter != .favorites }?.filter ?? tabs.first?.filter
    }

    /// The phrases for the selected tab.
    func selectedSection(for environment: SpeakEnvironment, everywhere: [Phrase]) -> PhraseSection? {
        guard let tab = selectedTab(for: environment, everywhere: everywhere) else { return nil }
        return section(tab, environment: environment, everywhere: everywhere)
    }

    /// Every section stacked: Favorites first, then categories.
    /// - Parameter includeEmpty: Include categories with no phrases.
    func sections(
        for environment: SpeakEnvironment,
        everywhere: [Phrase],
        includeEmpty: Bool = false
    ) -> [PhraseSection] {
        if let filter, filter != .all,
           let single = section(filter, environment: environment, everywhere: everywhere) {
            return [single]
        }
        var result: [PhraseSection] = []
        if let favorites = section(.favorites, environment: environment, everywhere: everywhere),
           !favorites.phrases.isEmpty {
            result.append(favorites)
        }
        result += environment.sortedCategories
            .filter { includeEmpty || !$0.phrases.isEmpty }
            .map(Self.section(for:))
        return result
    }

    private func section(_ filter: Filter, environment: SpeakEnvironment, everywhere: [Phrase]) -> PhraseSection? {
        switch filter {
        case .all:
            return nil
        case .favorites:
            return PhraseSection(id: Self.favoritesSectionID, title: Self.favoritesTitle,
                                 phrases: pinnedPhrases(in: environment, everywhere: everywhere))
        case .category(let id):
            return environment.sortedCategories.first { $0.id == id }.map(Self.section(for:))
        }
    }

    private static func section(for category: PhraseCategory) -> PhraseSection {
        PhraseSection(id: category.id.uuidString, title: category.name,
                      phrases: category.sortedPhrases, category: category)
    }
}
