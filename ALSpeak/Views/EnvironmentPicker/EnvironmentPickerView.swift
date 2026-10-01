import SwiftUI
import SwiftData

/// Home screen: "Where are you?" with a card per place, then favorites (one tap to speak).
/// The only other control is a settings button, so the screen stays calm.
struct EnvironmentPickerView: View {
    @Query(sort: \SpeakEnvironment.sortOrder) private var environments: [SpeakEnvironment]
    @Query(filter: #Predicate<Phrase> { $0.isFavorite }) private var favorites: [Phrase]

    @Environment(SpeechCoordinator.self) private var coordinator
    @Environment(\.modelContext) private var context
    @State private var isShowingSettings = false
    @State private var viewModel = EnvironmentPickerViewModel()

    @ScaledMetric(relativeTo: .title2) private var cardMinWidth: CGFloat = 150
    @ScaledMetric(relativeTo: .title3) private var phraseMinWidth: CGFloat = 160

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                section("Where are you?") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: cardMinWidth), spacing: 14)], spacing: 14) {
                        ForEach(viewModel.visibleEnvironments(environments)) { environment in
                            NavigationLink(value: environment) {
                                EnvironmentCard(
                                    name: environment.name,
                                    symbolName: environment.symbolName,
                                    colorKey: environment.colorKey
                                )
                            }
                            .buttonStyle(PressFeedbackButtonStyle())
                        }
                    }
                }

                let homeFavorites = viewModel.homeFavorites(favorites)
                if !homeFavorites.isEmpty {
                    section("Favorites") {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: phraseMinWidth), spacing: 12)], spacing: 12) {
                            ForEach(homeFavorites) { phrase in
                                PhraseButton(
                                    text: coordinator.displayText(for: phrase),
                                    colorKey: Palette.favoriteKey,
                                    isFavorite: true,
                                    missingTokens: coordinator.missingTokens(for: phrase)
                                ) {
                                    coordinator.speak(phrase)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(Palette.background)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.title3)
                }
                .accessibilityLabel("Settings")
                .accessibilityHint("Voice, places, personal details, emergency message and quick replies")
            }
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView(settings: UserSettings.current(in: context))
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.largeTitle.weight(.bold))
                .accessibilityAddTraits(.isHeader)
            content()
        }
    }
}

#Preview {
    NavigationStack {
        EnvironmentPickerView()
            .navigationDestination(for: SpeakEnvironment.self) { PhraseBoardView(environment: $0) }
    }
    .modelContainer(PreviewContainer.shared)
    .environment(PreviewContainer.coordinator)
    .fontDesign(.rounded)
}
