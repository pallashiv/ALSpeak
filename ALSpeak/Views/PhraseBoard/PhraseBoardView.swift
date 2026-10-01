import SwiftUI
import SwiftData

/// The phrases for one place, one category at a time. Tapping a phrase speaks it.
///
/// In edit mode, tapping a phrase opens its editor instead, the category gets an
/// "Add phrase" tile, and categories can be organized.
struct PhraseBoardView: View {
    let environment: SpeakEnvironment

    @Query(filter: #Predicate<Phrase> { $0.showEverywhere }) private var everywherePhrases: [Phrase]
    @Environment(SpeechCoordinator.self) private var coordinator
    @State private var viewModel = PhraseBoardViewModel()
    @State private var isEditing = false
    @State private var editingPhrase: PhraseEditorViewModel?
    @State private var isOrganizing = false

    @ScaledMetric(relativeTo: .title3) private var phraseMinWidth: CGFloat = 160
    @ScaledMetric(relativeTo: .title3) private var phraseMinHeight: CGFloat = 96

    var body: some View {
        let tabs = viewModel.tabs(for: environment, everywhere: everywherePhrases)
        let selected = viewModel.selectedTab(for: environment, everywhere: everywherePhrases)
        let section = viewModel.selectedSection(for: environment, everywhere: everywherePhrases)

        VStack(spacing: 0) {
            CategoryChipBar(tabs: tabs, selected: selected, colorKey: environment.colorKey) {
                viewModel.filter = $0
            }

            if isEditing {
                editingBanner
            }

            ScrollView {
                if let section, !(section.phrases.isEmpty && !isEditing) {
                    phraseGrid(section)
                        .padding(16)
                } else {
                    ContentUnavailableView {
                        Label("No phrases here yet", systemImage: "text.bubble")
                    } description: {
                        Text("Tap Edit to add some.")
                    }
                    .padding(.top, 60)
                }
            }
        }
        .background(Palette.background)
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
            .tint(Palette.environmentColor(environment.colorKey))
            .controlSize(.large)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Palette.soft(Palette.favoriteKey))
    }

    private func phraseGrid(_ section: PhraseSection) -> some View {
        let colorKey = section.category == nil ? Palette.favoriteKey : environment.colorKey
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: phraseMinWidth), spacing: 12)], spacing: 12) {
            ForEach(section.phrases) { phrase in
                PhraseButton(
                    text: coordinator.displayText(for: phrase),
                    colorKey: colorKey,
                    isFavorite: phrase.isFavorite,
                    missingTokens: coordinator.missingTokens(for: phrase),
                    accessibilityHint: isEditing ? "Edits this phrase" : "Speaks this phrase aloud",
                    usesTouchMode: !isEditing
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
        // Lets Switch Control scan the grid as a group.
        .accessibilityElement(children: .contain)
        .accessibilityLabel(section.title)
    }

    private func addPhraseTile(_ category: PhraseCategory) -> some View {
        let tint = Palette.accent(environment.colorKey)
        let shape = RoundedRectangle(cornerRadius: PhraseButton.cornerRadius, style: .continuous)
        return Button {
            editingPhrase = PhraseEditorViewModel(newIn: category)
        } label: {
            Label("Add phrase", systemImage: "plus")
                .font(.title3.weight(.semibold))
                .foregroundStyle(tint)
                .frame(maxWidth: .infinity, minHeight: phraseMinHeight)
                .background(shape.strokeBorder(tint, style: StrokeStyle(lineWidth: 2, dash: [8, 6])))
                .contentShape(shape)
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
    .fontDesign(.rounded)
}

#Preview("Family & Friends") {
    NavigationStack {
        PhraseBoardView(environment: PreviewContainer.environment(named: "Family & Friends"))
    }
    .modelContainer(PreviewContainer.shared)
    .environment(PreviewContainer.coordinator)
    .fontDesign(.rounded)
}
