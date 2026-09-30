import Foundation
import Observation

/// A titled block of phrases on the board.
struct PhraseSection: Identifiable {
    let id: String
    let title: String
    let phrases: [Phrase]
}

/// Decides which phrases the board shows, and in what order.
///
/// Layout rule: with "All" selected, the board shows a **Pinned** section first
/// (this environment's favorites + every "show everywhere" phrase), then every category.
/// So the most-used phrases are always two taps from home: environment → phrase.
@MainActor
@Observable
final class PhraseBoardViewModel {
    enum Filter: Hashable {
        case all
        case category(UUID)
    }

    var filter: Filter = .all

    static let pinnedSectionID = "pinned"

    /// Favorites from this environment, then "show everywhere" phrases from any environment,
    /// without duplicates.
    func pinnedPhrases(in environment: SpeakEnvironment, everywhere: [Phrase]) -> [Phrase] {
        var seen = Set<UUID>()
        let favorites = environment.allPhrases.filter(\.isFavorite)
        let shared = everywhere.sorted { $0.text.localizedCompare($1.text) == .orderedAscending }
        return (favorites + shared).filter { seen.insert($0.id).inserted }
    }

    func sections(for environment: SpeakEnvironment, everywhere: [Phrase]) -> [PhraseSection] {
        let categories = environment.sortedCategories

        if case .category(let id) = filter, let category = categories.first(where: { $0.id == id }) {
            return [PhraseSection(id: id.uuidString, title: category.name, phrases: category.sortedPhrases)]
        }

        // `.all`, or a category that no longer exists (e.g. deleted while selected).
        var result: [PhraseSection] = []
        let pinned = pinnedPhrases(in: environment, everywhere: everywhere)
        if !pinned.isEmpty {
            result.append(PhraseSection(id: Self.pinnedSectionID, title: "Pinned", phrases: pinned))
        }
        result += categories
            .filter { !$0.phrases.isEmpty }
            .map { PhraseSection(id: $0.id.uuidString, title: $0.name, phrases: $0.sortedPhrases) }
        return result
    }
}
