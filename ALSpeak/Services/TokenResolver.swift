import Foundation

/// Fills `{token}` placeholders in phrase text with the user's personal values.
///
/// Example: `"Could I have some {favoriteDrink}?"` with `["favoriteDrink": "iced tea"]`
/// becomes `"Could I have some iced tea?"`.
///
/// Tokens with no value (missing or blank) are left untouched so the UI can flag them
/// for a caregiver to fill in, rather than silently speaking a broken sentence.
enum TokenResolver {
    private static let regex = try! NSRegularExpression(pattern: #"\{([A-Za-z0-9_]+)\}"#)

    /// Returns `text` with every token that has a non-blank value replaced.
    static func resolve(_ text: String, tokens: [String: String]) -> String {
        var result = text as NSString
        // Replace from the end so earlier match ranges stay valid.
        for match in matches(in: text).reversed() {
            let key = result.substring(with: match.range(at: 1))
            guard let value = nonBlankValue(for: key, in: tokens) else { continue }
            result = result.replacingCharacters(in: match.range, with: value) as NSString
        }
        return result as String
    }

    /// Text suitable for speaking: known tokens are filled in and any still-missing tokens
    /// are dropped, so the synthesizer never reads out "{caregiverName}".
    /// e.g. "Get my caregiver {caregiverName}" → "Get my caregiver".
    static func resolveForSpeech(_ text: String, tokens: [String: String]) -> String {
        let resolved = resolve(text, tokens: tokens) as NSString
        let stripped = regex.stringByReplacingMatches(
            in: resolved as String,
            range: NSRange(location: 0, length: resolved.length),
            withTemplate: ""
        )
        return stripped
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+([.,!?;:])"#, with: "$1", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Token names used in `text`, in order of appearance, without duplicates.
    static func tokenNames(in text: String) -> [String] {
        let ns = text as NSString
        var seen = Set<String>()
        return matches(in: text).compactMap { match in
            let key = ns.substring(with: match.range(at: 1))
            return seen.insert(key).inserted ? key : nil
        }
    }

    /// Token names used in `text` that have no value yet.
    static func missingTokens(in text: String, tokens: [String: String]) -> [String] {
        tokenNames(in: text).filter { nonBlankValue(for: $0, in: tokens) == nil }
    }

    private static func matches(in text: String) -> [NSTextCheckingResult] {
        regex.matches(in: text, range: NSRange(location: 0, length: (text as NSString).length))
    }

    private static func nonBlankValue(for key: String, in tokens: [String: String]) -> String? {
        guard let value = tokens[key]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else { return nil }
        return value
    }
}
