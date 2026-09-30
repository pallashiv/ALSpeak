import Foundation
import Observation

/// Home-screen logic. Editing (add / rename / reorder / hide) arrives in phase (c).
@MainActor
@Observable
final class EnvironmentPickerViewModel {
    /// Environments to show as cards, in the user's order.
    func visibleEnvironments(_ environments: [SpeakEnvironment]) -> [SpeakEnvironment] {
        environments
            .filter { !$0.isHidden }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    /// Favorites shown on the home screen so a phrase can be spoken in a single tap from launch.
    ///
    /// The order is deliberately stable (environment → category → phrase order) rather than
    /// "most recent first": buttons that move after every tap break motor memory.
    func homeFavorites(_ favorites: [Phrase]) -> [Phrase] {
        favorites
            .filter { !($0.environment?.isHidden ?? false) }
            .sorted { Self.boardPosition($0).lexicographicallyPrecedes(Self.boardPosition($1)) }
    }

    private static func boardPosition(_ phrase: Phrase) -> [Int] {
        [
            phrase.environment?.sortOrder ?? .max,
            phrase.category?.sortOrder ?? .max,
            phrase.sortOrder,
        ]
    }
}
