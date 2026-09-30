import SwiftUI
import SwiftData

/// Top-level layout: navigation (home → phrase board) with the spoken-phrase overlay on top.
///
/// Phase (d) adds the Quick Respond bar and Emergency button *outside* the overlay, so
/// they stay reachable even while a phrase is displayed full-screen.
struct RootView: View {
    @Environment(SpeechCoordinator.self) private var coordinator

    var body: some View {
        NavigationStack {
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
                    onRepeat: coordinator.repeatDisplayed,
                    onStop: coordinator.stopSpeaking,
                    onClose: coordinator.dismissDisplay
                )
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.15), value: coordinator.displayedText)
    }
}

#Preview {
    RootView()
        .modelContainer(PreviewContainer.shared)
        .environment(PreviewContainer.coordinator)
}
