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
        #if DEBUG
        Self.applyDemoProfileIfRequested(in: container.mainContext)
        #endif
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

    #if DEBUG
    /// `-DemoProfile` fills in sample personal details, for screenshots and demo recordings.
    private static func applyDemoProfileIfRequested(in context: ModelContext) {
        guard ProcessInfo.processInfo.arguments.contains(LaunchArgument.demoProfile) else { return }
        let settings = UserSettings.current(in: context)
        settings.tokens["name"] = "Alex"
        settings.tokens["caregiverName"] = "Jordan"
        try? context.save()
    }
    #endif

    /// The user's voice must never be unavailable. If the on-disk store can't be opened,
    /// fall back to an in-memory store (seeded with the default library) so the app still
    /// launches and speaks, rather than crashing.
    private static func makeContainer() -> ModelContainer {
        do {
            // UI tests start from a fresh, seeded library every launch.
            let isUITesting = ProcessInfo.processInfo.arguments.contains(LaunchArgument.uiTesting)
            return try AppSchema.makeContainer(inMemory: isUITesting)
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

/// Launch arguments understood by the app.
enum LaunchArgument {
    /// Use a fresh in-memory store (set by the UI tests).
    static let uiTesting = "-UITesting"
    /// Debug only: open the named place on launch, e.g. `-OpenPlace Restaurant`.
    static let openPlace = "-OpenPlace"
    /// Debug only: speak and display text on launch, e.g. `-ShowSpoken "Hello"`.
    static let showSpoken = "-ShowSpoken"
    /// Debug only: fill in a sample name and caregiver for demos.
    static let demoProfile = "-DemoProfile"
}

extension Logger {
    static let app = Logger(subsystem: "com.shivpalla.ALSpeak", category: "app")
}
