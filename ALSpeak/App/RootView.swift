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
///
/// It also turns `UserSettings` into app-wide environment values (theme, touch mode).
struct RootView: View {
    @Environment(SpeechCoordinator.self) private var coordinator
    @Environment(\.colorSchemeContrast) private var systemContrast
    @Query private var settingsRecords: [UserSettings]

    @State private var path: [SpeakEnvironment] = []
    @State private var isTyping = false

    private var settings: UserSettings? { settingsRecords.first }

    private var theme: AppTheme {
        AppTheme.resolve(settings?.theme ?? .standard, systemIncreasedContrast: systemContrast == .increased)
    }

    private var selectionStyle: SelectionStyle {
        SelectionStyle(mode: settings?.touchMode ?? .tap, duration: settings?.dwellDuration ?? 0.8)
    }

    var body: some View {
        VStack(spacing: 0) {
            NavigationStack(path: $path) {
                EnvironmentPickerView()
                    .navigationDestination(for: SpeakEnvironment.self) { environment in
                        PhraseBoardView(environment: environment)
                    }
            }
            .overlay { spokenPhraseDisplay }
            .animation(.easeOut(duration: 0.15), value: coordinator.displayedText)

            QuickRespondBar(onType: { isTyping = true })
        }
        .sheet(isPresented: $isTyping) {
            // The place on screen when typing started, so "Save" can file the phrase there.
            TypeToSpeakView(currentEnvironment: path.last)
        }
        .environment(\.appTheme, theme)
        .environment(\.selectionStyle, selectionStyle)
        .preferredColorScheme(theme == .highContrast ? .dark : nil)
        .task(id: settings?.keepScreenOn) {
            UIApplication.shared.isIdleTimerDisabled = settings?.keepScreenOn ?? true
        }
    }

    /// Full-screen display for the listener, or a small banner if the user turned that off.
    /// Emergency alerts are always full-screen.
    @ViewBuilder
    private var spokenPhraseDisplay: some View {
        if let text = coordinator.displayedText {
            if coordinator.isDisplayingEmergency || settings?.showFullScreenPhrase ?? true {
                SpokenPhraseOverlay(
                    text: text,
                    isSpeaking: coordinator.speech.isSpeaking,
                    isEmergency: coordinator.isDisplayingEmergency,
                    onRepeat: coordinator.repeatDisplayed,
                    onStop: coordinator.stopSpeaking,
                    onClose: coordinator.dismissDisplay
                )
                .transition(.opacity)
            } else {
                SpokenPhraseBanner(text: text, onClose: coordinator.dismissDisplay)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .transition(.opacity)
            }
        }
    }
}

/// Compact "just spoke" confirmation used when the full-screen display is turned off.
struct SpokenPhraseBanner: View {
    let text: String
    let onClose: () -> Void

    var body: some View {
        Button(action: onClose) {
            Label(text, systemImage: "speaker.wave.2.fill")
                .font(.headline)
                .lineLimit(3)
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.black.opacity(0.88), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .accessibilityLabel("Spoke: \(text)")
        .accessibilityHint("Closes this message")
    }
}

#Preview {
    RootView()
        .modelContainer(PreviewContainer.shared)
        .environment(PreviewContainer.coordinator)
}

#Preview("Banner") {
    SpokenPhraseBanner(text: "Could I see the menu?", onClose: {})
}
