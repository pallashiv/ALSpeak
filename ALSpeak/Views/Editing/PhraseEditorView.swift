import SwiftUI
import SwiftData

/// Sheet for adding or editing a single phrase.
struct PhraseEditorView: View {
    @Bindable var viewModel: PhraseEditorViewModel

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(SpeechCoordinator.self) private var coordinator
    @State private var isConfirmingDelete = false

    @ScaledMetric(relativeTo: .body) private var tokenMinWidth: CGFloat = 150

    private var editor: PhraseLibraryEditor { PhraseLibraryEditor(context: context) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("What do you want to say?", text: $viewModel.text, axis: .vertical)
                        .font(.title3)
                        .lineLimit(2...8)
                        .accessibilityLabel("Phrase text")

                    Button {
                        coordinator.preview(text: viewModel.trimmedText)
                    } label: {
                        Label("Hear it", systemImage: "speaker.wave.2.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .disabled(viewModel.trimmedText.isEmpty)
                } header: {
                    Text("Phrase")
                }

                if !coordinator.availableTokens.isEmpty {
                    Section {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: tokenMinWidth), spacing: 8)], spacing: 8) {
                            ForEach(coordinator.availableTokens, id: \.self) { token in
                                Button {
                                    viewModel.insertToken(token)
                                } label: {
                                    Text("{\(token)}")
                                        .font(.body.monospaced())
                                        .frame(maxWidth: .infinity, minHeight: 44)
                                }
                                .buttonStyle(.bordered)
                                .accessibilityLabel("Insert \(token)")
                            }
                        }
                        .padding(.vertical, 4)
                    } header: {
                        Text("Insert a personal detail")
                    } footer: {
                        Text("Filled in from Settings when the phrase is spoken.")
                    }
                }

                if viewModel.categories.count > 1 {
                    Section("Category") {
                        Picker("Category", selection: $viewModel.categoryID) {
                            ForEach(viewModel.categories) { category in
                                Text(category.name).tag(Optional(category.id))
                            }
                        }
                    }
                }

                Section {
                    Toggle("Favorite", isOn: $viewModel.isFavorite)
                    Toggle("Show in every place", isOn: $viewModel.showEverywhere)
                } footer: {
                    Text("Favorites appear on the home screen. Phrases shown in every place appear at the top of every board.")
                }

                if !viewModel.isNew {
                    Section {
                        Button("Delete phrase", role: .destructive) {
                            isConfirmingDelete = true
                        }
                        .frame(maxWidth: .infinity, minHeight: 44)
                    }
                }
            }
            .navigationTitle(viewModel.isNew ? "New Phrase" : "Edit Phrase")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.save(using: editor)
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .disabled(!viewModel.canSave)
                }
            }
            .confirmationDialog("Delete this phrase?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    viewModel.delete(using: editor)
                    dismiss()
                }
            } message: {
                Text("“\(viewModel.trimmedText)” will be removed. This can't be undone.")
            }
        }
    }
}

#Preview("Edit") {
    let phrase = PreviewContainer.environment(named: "Restaurant").allPhrases[0]
    return PhraseEditorView(viewModel: PhraseEditorViewModel(phrase: phrase))
        .modelContainer(PreviewContainer.shared)
        .environment(PreviewContainer.coordinator)
}

#Preview("New") {
    let category = PreviewContainer.environment(named: "Home").sortedCategories[0]
    return PhraseEditorView(viewModel: PhraseEditorViewModel(newIn: category))
        .modelContainer(PreviewContainer.shared)
        .environment(PreviewContainer.coordinator)
}
