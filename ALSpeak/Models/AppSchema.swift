import Foundation
import SwiftData

/// Central place that knows every persisted model type and how to build the container.
enum AppSchema {
    static let models: [any PersistentModel.Type] = [
        SpeakEnvironment.self,
        PhraseCategory.self,
        Phrase.self,
        UserSettings.self,
    ]

    /// Builds the SwiftData container.
    /// - Parameter inMemory: Use for tests and previews. Each in-memory container gets a
    ///   unique name so parallel tests never share state.
    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(models)
        let configuration = inMemory
            ? ModelConfiguration(UUID().uuidString, schema: schema, isStoredInMemoryOnly: true)
            : ModelConfiguration(schema: schema)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
