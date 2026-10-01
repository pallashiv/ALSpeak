import SwiftUI
import SwiftData

/// Top-level layout:
///
///     ┌──────────────────────────────┐
///     │ NavigationStack              │  home → phrase board
///     │   (spoken-phrase overlay     │  covers only this area…
///     │    sits on top of it)        │
///     ├──────────────────────────────┤
///     │ ⌨︎ | Quick replies… | ⚠︎ HOLD │  …so this bar stays usable mid-conversation
///     └──────────────────────────────┘
struct RootView: View {
    @Environment(SpeechCoordinator.self) private var coordinator
    @State private var path: [SpeakEnvironment] = []
    @State private var isTyping = false

    var body: some View {
        VStack(spacing: 0) {
            NavigationStack(path: $path) {
                EnvironmentPickerView()
                    .navigationDestination(for: SpeakEnvironment.self) { environment in
                        PhraseBoardView(environment: environment)
                    }
            }
            .overlay {
                if let text = coordinator.displayedText {
                    SpokenPhraseOverlay(
                        text: text,
                        isSpeaking: coordinator.speech.isSpeaking,
                        isEmergency: coordinator.isDisplayingEmergency,
                        onRepeat: coordinator.repeatDisplayed,
                        onStop: coordinator.stopSpeaking,
                        onClose: coordinator.dismissDisplay
                    )
                    .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.15), value: coordinator.displayedText)

            QuickRespondBar(onType: { isTyping = true })
        }
        .sheet(isPresented: $isTyping) {
            // The place on screen when typing started, so "Save" can file the phrase there.
            TypeToSpeakView(currentEnvironment: path.last)
        }
    }
}

#Preview {
    RootView()
        .modelContainer(PreviewContainer.shared)
        .environment(PreviewContainer.coordinator)
}
