import SwiftUI
import SwiftData

/// The phrase grid for one environment. Tapping a phrase speaks it immediately.
struct PhraseBoardView: View {
    let environment: SpeakEnvironment

    @Query(filter: #Predicate<Phrase> { $0.showEverywhere }) private var everywherePhrases: [Phrase]
    @Environment(SpeechCoordinator.self) private var coordinator
    @State private var viewModel = PhraseBoardViewModel()

    @ScaledMetric(relativeTo: .title3) private var phraseMinWidth: CGFloat = 220

    private var tint: Color { Palette.environmentColor(environment.colorKey) }

    var body: some View {
        VStack(spacing: 0) {
            CategoryChipBar(categories: environment.sortedCategories, filter: $viewModel.filter, tint: tint)
            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    ForEach(viewModel.sections(for: environment, everywhere: everywherePhrases)) { section in
                        sectionView(section)
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle(environment.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func sectionView(_ section: PhraseSection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(section.title)
                .font(.title3.weight(.bold))
                .accessibilityAddTraits(.isHeader)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: phraseMinWidth), spacing: 12)], spacing: 12) {
                ForEach(section.phrases) { phrase in
                    PhraseButton(
                        text: coordinator.displayText(for: phrase),
                        tint: section.id == PhraseBoardViewModel.pinnedSectionID ? Palette.pinned : tint,
                        isFavorite: phrase.isFavorite,
                        missingTokens: coordinator.missingTokens(for: phrase)
                    ) {
                        coordinator.speak(phrase)
                    }
                }
            }
        }
    }
}

#Preview("Restaurant") {
    NavigationStack {
        PhraseBoardView(environment: PreviewContainer.environment(named: "Restaurant"))
    }
    .modelContainer(PreviewContainer.shared)
    .environment(PreviewContainer.coordinator)
}

#Preview("Family & Friends") {
    NavigationStack {
        PhraseBoardView(environment: PreviewContainer.environment(named: "Family & Friends"))
    }
    .modelContainer(PreviewContainer.shared)
    .environment(PreviewContainer.coordinator)
}
