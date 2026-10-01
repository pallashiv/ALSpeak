import Foundation
import Observation

/// Logic for the type-to-speak screen: suggestions while typing, the recent list, and
/// one-tap saving of typed text as a phrase.
@MainActor
@Observable
final class TypeToSpeakViewModel {
    /// A tappable suggestion: either a library phrase or a recently typed text.
    struct Suggestion: Identifiable, Equatable {
        let text: String
        /// Set when the suggestion comes from the library, so its usage can be recorded.
        let phrase: Phrase?
        var id: String { text.lowercased() }

        static func == (lhs: Suggestion, rhs: Suggestion) -> Bool { lhs.id == rhs.id }
    }

    /// Category that typed phrases are saved into (created on first save).
    static let savedCategoryName = "My Phrases"
    static let maxRecents = 10
    static let minimumQueryLength = 2

    var text = ""

    var trimmedText: String { text.trimmed }
    var canSpeak: Bool { !trimmedText.isEmpty }

    // MARK: Suggestions

    /// Library phrases and recent texts that match what has been typed so far.
    ///
    /// Ranking: text that starts with the query, then text with a word starting with the
    /// query, then text containing it; ties go to recently typed texts, then to the most
    /// used library phrases.
    func suggestions(
        phrases: [Phrase],
        recents: [String],
        tokens: [String: String],
        limit: Int = 4
    ) -> [Suggestion] {
        let query = trimmedText.lowercased()
        guard query.count >= Self.minimumQueryLength else { return [] }

        struct Candidate {
            let suggestion: Suggestion
            let rank: Int
            let tiebreak: Int
        }

        var seen = Set<String>([query])
        var candidates: [Candidate] = []

        func consider(_ text: String, phrase: Phrase?, tiebreak: Int) {
            let lowered = text.lowercased()
            guard let rank = Self.matchRank(of: query, in: lowered), seen.insert(lowered).inserted else { return }
            candidates.append(Candidate(suggestion: Suggestion(text: text, phrase: phrase), rank: rank, tiebreak: tiebreak))
        }

        for (index, recent) in recents.enumerated() {
            consider(recent, phrase: nil, tiebreak: -1_000_000 + index)
        }
        for phrase in phrases {
            consider(TokenResolver.resolveForSpeech(phrase.text, tokens: tokens), phrase: phrase, tiebreak: -phrase.useCount)
        }

        return candidates
            .sorted { ($0.rank, $0.tiebreak) < ($1.rank, $1.tiebreak) }
            .prefix(limit)
            .map(\.suggestion)
    }

    /// 0 = prefix match, 1 = word-prefix match, 2 = substring match, nil = no match.
    static func matchRank(of query: String, in text: String) -> Int? {
        if text.hasPrefix(query) { return 0 }
        let words = text.split { !$0.isLetter && !$0.isNumber && $0 != "'" }
        if words.contains(where: { $0.hasPrefix(query) }) { return 1 }
        if text.contains(query) { return 2 }
        return nil
    }

    // MARK: Recents

    /// Puts the current text at the top of the recent list (no duplicates, capped).
    func recordSpoken(in settings: UserSettings) {
        let text = trimmedText
        guard !text.isEmpty else { return }
        let others = settings.recentTypedTexts.filter { $0.caseInsensitiveCompare(text) != .orderedSame }
        settings.recentTypedTexts = Array(([text] + others).prefix(Self.maxRecents))
    }

    // MARK: Saving

    /// Saves the typed text as a phrase in `environment`'s "My Phrases" category.
    @discardableResult
    func save(to environment: SpeakEnvironment, using editor: PhraseLibraryEditor) -> Phrase? {
        guard canSpeak else { return nil }
        let category = environment.categories.first { $0.name == Self.savedCategoryName }
            ?? editor.addCategory(named: Self.savedCategoryName, to: environment)
        return editor.addPhrase(text: trimmedText, to: category)
    }
}
