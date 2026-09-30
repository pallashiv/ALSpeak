#if DEBUG
import Foundation
import SwiftData

/// In-memory container seeded with the real bundled library, for SwiftUI previews.
@MainActor
enum PreviewContainer {
    static let shared: ModelContainer = {
        do {
            let container = try AppSchema.makeContainer(inMemory: true)
            try SeedDataLoader.seedIfNeeded(context: container.mainContext)
            return container
        } catch {
            fatalError("Preview container failed: \(error)")
        }
    }()

    /// Speech coordinator backed by the preview container (really speaks in live previews).
    static let coordinator = SpeechCoordinator(speech: SpeechService(), context: shared.mainContext)

    /// First seeded environment of the given name, for previewing a single board.
    static func environment(named name: String) -> SpeakEnvironment {
        let descriptor = FetchDescriptor<SpeakEnvironment>(predicate: #Predicate { $0.name == name })
        guard let environment = try? shared.mainContext.fetch(descriptor).first else {
            fatalError("No preview environment named \(name)")
        }
        return environment
    }
}
#endif
