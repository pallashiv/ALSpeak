import SwiftUI
import SwiftData
import os

@main
struct ALSpeakApp: App {
    private let container: ModelContainer
    /// App-wide speech entry point, shared with every view through the environment.
    @State private var coordinator: SpeechCoordinator

    init() {
        let container = Self.makeContainer()
        do {
            try SeedDataLoader.seedIfNeeded(context: container.mainContext)
        } catch {
            Logger.app.error("Seeding failed: \(error.localizedDescription)")
        }
        self.container = container
        _coordinator = State(initialValue: SpeechCoordinator(speech: SpeechService(), context: container.mainContext))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(coordinator)
        }
        .modelContainer(container)
    }

    /// The user's voice must never be unavailable. If the on-disk store can't be opened,
    /// fall back to an in-memory store (seeded with the default library) so the app still
    /// launches and speaks, rather than crashing.
    private static func makeContainer() -> ModelContainer {
        do {
            return try AppSchema.makeContainer()
        } catch {
            Logger.app.fault("Persistent store failed, using in-memory store: \(error.localizedDescription)")
            do {
                return try AppSchema.makeContainer(inMemory: true)
            } catch {
                fatalError("Could not create even an in-memory ModelContainer: \(error)")
            }
        }
    }
}

extension Logger {
    static let app = Logger(subsystem: "com.shivpalla.ALSpeak", category: "app")
}
