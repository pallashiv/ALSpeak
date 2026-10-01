import SwiftUI
import SwiftData

/// The phrase grid for one environment. Tapping a phrase speaks it immediately.
///
/// In edit mode, tapping a phrase opens its editor instead, each category gets an
/// "Add phrase" tile, and categories can be organized.
struct PhraseBoardView: View {
    let environment: SpeakEnvironment

    @Query(filter: #Predicate<Phrase> { $0.showEverywhere }) private var everywherePhrases: [Phrase]
    @Environment(SpeechCoordinator.self) private var coordinator
    @State private var viewModel = PhraseBoardViewModel()
    @State private var isEditing = false
    @State private var editingPhrase: PhraseEditorViewModel?
    @State private var isOrganizing = false

    @ScaledMetric(relativeTo: .title3) private var phraseMinWidth: CGFloat = 220
    @ScaledMetric(relativeTo: .title3) private var phraseMinHeight: CGFloat = 88

    private var tint: Color { Palette.environmentColor(environment.colorKey) }

    var body: some View {
        let sections = viewModel.sections(for: environment, everywhere: everywherePhrases, includeEmpty: isEditing)

        VStack(spacing: 0) {
            CategoryChipBar(categories: environment.sortedCategories, filter: $viewModel.filter, tint: tint)
            Divider()

            if isEditing {
                editingBanner
            }

            if sections.isEmpty {
                ContentUnavailableView {
                    Label("No phrases yet", systemImage: "text.bubble")
                } description: {
                    Text("Tap Edit to add phrases to \(environment.name).")
                }
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 24) {
                        ForEach(sections) { section in
                            sectionView(section)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .navigationTitle(environment.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(isEditing ? "Done" : "Edit") {
                    isEditing.toggle()
                }
                .font(.headline)
                .accessibilityHint(isEditing ? "Return to speaking" : "Add, change or remove phrases")
            }
        }
        .sheet(item: $editingPhrase) { viewModel in
            PhraseEditorView(viewModel: viewModel)
        }
        .sheet(isPresented: $isOrganizing) {
            OrganizeCategoriesView(environment: environment)
        }
    }

    private var editingBanner: some View {
        HStack(spacing: 12) {
            Label("Tap a phrase to change it", systemImage: "pencil")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Categories") {
                isOrganizing = true
            }
            .buttonStyle(.borderedProminent)
            .tint(tint)
            .controlSize(.large)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.yellow.opacity(0.25))
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
                        missingTokens: coordinator.missingTokens(for: phrase),
                        accessibilityHint: isEditing ? "Edits this phrase" : "Speaks this phrase aloud"
                    ) {
                        if isEditing {
                            editingPhrase = PhraseEditorViewModel(phrase: phrase)
                        } else {
                            coordinator.speak(phrase)
                        }
                    }
                }

                if isEditing, let category = section.category {
                    addPhraseTile(category)
                }
            }
        }
    }

    private func addPhraseTile(_ category: PhraseCategory) -> some View {
        Button {
            editingPhrase = PhraseEditorViewModel(newIn: category)
        } label: {
            Label("Add phrase", systemImage: "plus")
                .font(.title3.weight(.semibold))
                .foregroundStyle(tint)
                .frame(maxWidth: .infinity, minHeight: phraseMinHeight)
                .background {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(tint, style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                }
                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(PressFeedbackButtonStyle())
        .accessibilityLabel("Add phrase to \(category.name)")
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
