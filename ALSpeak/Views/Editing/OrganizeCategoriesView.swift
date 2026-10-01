import SwiftUI
import SwiftData

/// Add, rename, reorder and delete the categories of one place, and drill into each
/// category to reorder its phrases.
struct OrganizeCategoriesView: View {
    let environment: SpeakEnvironment

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var pendingDeletion: PhraseCategory?
    @State private var isAddingCategory = false
    @State private var newCategoryName = ""

    private var editor: PhraseLibraryEditor { PhraseLibraryEditor(context: context) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(environment.sortedCategories) { category in
                        NavigationLink {
                            CategoryPhrasesView(category: category)
                        } label: {
                            LabeledContent(category.name.isEmpty ? "Untitled" : category.name,
                                           value: "\(category.phrases.count)")
                                .font(.headline)
                                .frame(minHeight: 44)
                        }
                    }
                    .onMove { editor.moveCategories(in: environment, from: $0, to: $1) }
                    .onDelete { offsets in
                        let categories = environment.sortedCategories
                        pendingDeletion = offsets.first.map { categories[$0] }
                    }
                } header: {
                    Text("Categories")
                } footer: {
                    Text("Tap a category to rename it or reorder its phrases. Tap Edit to reorder or delete categories.")
                }

                Section {
                    Button {
                        newCategoryName = ""
                        isAddingCategory = true
                    } label: {
                        Label("Add a category", systemImage: "plus.circle.fill")
                            .font(.headline)
                            .frame(minHeight: 44)
                    }
                }
            }
            .navigationTitle("\(environment.name) Categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.bold)
                }
            }
            .alert("New category", isPresented: $isAddingCategory) {
                TextField("Name", text: $newCategoryName)
                Button("Add") {
                    guard !newCategoryName.trimmed.isEmpty else { return }
                    editor.addCategory(named: newCategoryName, to: environment)
                }
                Button("Cancel", role: .cancel) {}
            }
            .confirmationDialog(
                "Delete \(pendingDeletion?.name ?? "this category")?",
                isPresented: Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } }),
                titleVisibility: .visible,
                presenting: pendingDeletion
            ) { category in
                Button("Delete category and its phrases", role: .destructive) {
                    editor.delete(category)
                }
            } message: { category in
                Text("This removes \(category.phrases.count) phrases and can't be undone.")
            }
        }
    }
}

/// One category: rename it, reorder / delete its phrases, or add new ones.
struct CategoryPhrasesView: View {
    @Bindable var category: PhraseCategory

    @Environment(\.modelContext) private var context
    @State private var editingPhrase: PhraseEditorViewModel?

    private var editor: PhraseLibraryEditor { PhraseLibraryEditor(context: context) }

    var body: some View {
        List {
            Section("Category name") {
                TextField("Name", text: $category.name)
                    .font(.title3)
                    .onSubmit { editor.rename(category, to: category.name) }
            }

            Section("Phrases") {
                ForEach(category.sortedPhrases) { phrase in
                    Button {
                        editingPhrase = PhraseEditorViewModel(phrase: phrase)
                    } label: {
                        HStack {
                            Text(phrase.text)
                                .foregroundStyle(Color.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            if phrase.isFavorite {
                                Image(systemName: "star.fill").accessibilityLabel("Favorite")
                            }
                            if phrase.showEverywhere {
                                Image(systemName: "globe").accessibilityLabel("Shown in every place")
                            }
                        }
                        .frame(minHeight: 44)
                    }
                }
                .onMove { editor.movePhrases(in: category, from: $0, to: $1) }
                .onDelete { offsets in
                    let phrases = category.sortedPhrases
                    offsets.map { phrases[$0] }.forEach(editor.delete)
                }

                Button {
                    editingPhrase = PhraseEditorViewModel(newIn: category)
                } label: {
                    Label("Add a phrase", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .frame(minHeight: 44)
                }
            }
        }
        .navigationTitle(category.name.isEmpty ? "Untitled" : category.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { EditButton() }
        .sheet(item: $editingPhrase) { viewModel in
            PhraseEditorView(viewModel: viewModel)
        }
        .onDisappear { editor.rename(category, to: category.name) }
    }
}

#Preview("Categories") {
    OrganizeCategoriesView(environment: PreviewContainer.environment(named: "Restaurant"))
        .modelContainer(PreviewContainer.shared)
        .environment(PreviewContainer.coordinator)
}

#Preview("Category phrases") {
    NavigationStack {
        CategoryPhrasesView(category: PreviewContainer.environment(named: "Home").sortedCategories[0])
    }
    .modelContainer(PreviewContainer.shared)
    .environment(PreviewContainer.coordinator)
}
