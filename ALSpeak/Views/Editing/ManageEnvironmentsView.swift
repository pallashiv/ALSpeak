import SwiftUI
import SwiftData

/// Add, rename, reorder, hide and delete places (environments).
struct ManageEnvironmentsView: View {
    @Query(sort: \SpeakEnvironment.sortOrder) private var environments: [SpeakEnvironment]

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var editing: EnvironmentEditorViewModel?
    @State private var pendingDeletion: SpeakEnvironment?

    private var editor: PhraseLibraryEditor { PhraseLibraryEditor(context: context) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(environments) { environment in
                        row(environment)
                    }
                    .onMove { editor.moveEnvironments(environments, from: $0, to: $1) }
                    .onDelete { offsets in
                        pendingDeletion = offsets.first.map { environments[$0] }
                    }
                } footer: {
                    Text("Drag to reorder. Hidden places keep their phrases but don't appear on the home screen.")
                }

                Section {
                    Button {
                        editing = EnvironmentEditorViewModel()
                    } label: {
                        Label("Add a place", systemImage: "plus.circle.fill")
                            .font(.headline)
                            .frame(minHeight: 44)
                    }
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Edit Places")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.bold)
                }
            }
            .sheet(item: $editing) { viewModel in
                EnvironmentEditorView(viewModel: viewModel)
            }
            .confirmationDialog(
                "Delete \(pendingDeletion?.name ?? "this place")?",
                isPresented: Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } }),
                titleVisibility: .visible,
                presenting: pendingDeletion
            ) { environment in
                Button("Delete place and its phrases", role: .destructive) {
                    editor.delete(environment)
                }
                Button("Hide it instead") {
                    editor.setHidden(environment, true)
                }
            } message: { environment in
                Text("This removes \(environment.allPhrases.count) phrases and can't be undone. Hiding keeps them.")
            }
        }
    }

    private func row(_ environment: SpeakEnvironment) -> some View {
        HStack(spacing: 12) {
            Image(systemName: environment.symbolName)
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Palette.environmentColor(environment.colorKey),
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(environment.name)
                    .font(.headline)
                if environment.isHidden {
                    Text("Hidden")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                editor.setHidden(environment, !environment.isHidden)
            } label: {
                Image(systemName: environment.isHidden ? "eye.slash" : "eye")
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel(environment.isHidden ? "Show \(environment.name)" : "Hide \(environment.name)")

            Button {
                editing = EnvironmentEditorViewModel(environment: environment)
            } label: {
                Image(systemName: "pencil")
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Edit \(environment.name)")
        }
        .opacity(environment.isHidden ? 0.6 : 1)
        .padding(.vertical, 4)
    }
}

#Preview {
    ManageEnvironmentsView()
        .modelContainer(PreviewContainer.shared)
}
