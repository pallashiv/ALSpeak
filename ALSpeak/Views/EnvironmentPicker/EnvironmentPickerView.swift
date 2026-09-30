import SwiftUI
import SwiftData

/// Home screen: favorites (one tap to speak) above a grid of environment cards.
struct EnvironmentPickerView: View {
    @Query(sort: \SpeakEnvironment.sortOrder) private var environments: [SpeakEnvironment]
    @Query(filter: #Predicate<Phrase> { $0.isFavorite }) private var favorites: [Phrase]

    @Environment(SpeechCoordinator.self) private var coordinator
    @State private var viewModel = EnvironmentPickerViewModel()

    @ScaledMetric(relativeTo: .title2) private var cardMinWidth: CGFloat = 160
    @ScaledMetric(relativeTo: .title3) private var phraseMinWidth: CGFloat = 220

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                let homeFavorites = viewModel.homeFavorites(favorites)
                if !homeFavorites.isEmpty {
                    section("Favorites") {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: phraseMinWidth), spacing: 12)], spacing: 12) {
                            ForEach(homeFavorites) { phrase in
                                PhraseButton(
                                    text: coordinator.displayText(for: phrase),
                                    tint: Palette.pinned,
                                    isFavorite: true,
                                    missingTokens: coordinator.missingTokens(for: phrase)
                                ) {
                                    coordinator.speak(phrase)
                                }
                            }
                        }
                    }
                }

                section("Where are you?") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: cardMinWidth), spacing: 12)], spacing: 12) {
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
            }
            .padding(16)
        }
        .navigationTitle("ALSpeak")
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title2.weight(.bold))
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
}
