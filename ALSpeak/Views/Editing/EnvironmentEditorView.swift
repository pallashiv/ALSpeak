import SwiftUI
import SwiftData

/// Sheet for adding or editing a place: name, color and icon, with a live card preview.
struct EnvironmentEditorView: View {
    @Bindable var viewModel: EnvironmentEditorViewModel

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @ScaledMetric(relativeTo: .body) private var swatchSize: CGFloat = 60

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    EnvironmentCard(
                        name: viewModel.trimmedName.isEmpty ? "New place" : viewModel.trimmedName,
                        symbolName: viewModel.symbolName,
                        colorKey: viewModel.colorKey
                    )
                    .accessibilityHidden(true)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                Section("Name") {
                    TextField("For example: Church, Work, Car", text: $viewModel.name)
                        .font(.title3)
                        .accessibilityLabel("Place name")
                }

                Section("Color") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: swatchSize), spacing: 12)], spacing: 12) {
                        ForEach(Palette.environmentColorKeys, id: \.self) { key in
                            swatch(key)
                        }
                    }
                    .padding(.vertical, 6)
                }

                Section("Icon") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: swatchSize), spacing: 12)], spacing: 12) {
                        ForEach(EnvironmentEditorViewModel.symbolChoices) { choice in
                            iconTile(choice)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
            .navigationTitle(viewModel.isNew ? "New Place" : "Edit Place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.save(using: PhraseLibraryEditor(context: context))
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .disabled(!viewModel.canSave)
                }
            }
        }
    }

    private func swatch(_ key: String) -> some View {
        let isSelected = viewModel.colorKey == key
        return Button {
            viewModel.colorKey = key
        } label: {
            Circle()
                .fill(Palette.environmentColor(key))
                .frame(width: swatchSize, height: swatchSize)
                .overlay {
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)
                    }
                }
                .overlay(Circle().strokeBorder(Color.primary, lineWidth: isSelected ? 3 : 0))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(key.capitalized)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func iconTile(_ choice: EnvironmentEditorViewModel.SymbolChoice) -> some View {
        let isSelected = viewModel.symbolName == choice.symbol
        let tint = Palette.environmentColor(viewModel.colorKey)
        return Button {
            viewModel.symbolName = choice.symbol
        } label: {
            Image(systemName: choice.symbol)
                .font(.title2)
                .frame(width: swatchSize, height: swatchSize)
                .foregroundStyle(isSelected ? .white : tint)
                .background(isSelected ? tint : Color(.secondarySystemBackground),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(choice.label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview("New") {
    EnvironmentEditorView(viewModel: EnvironmentEditorViewModel())
        .modelContainer(PreviewContainer.shared)
}

#Preview("Edit") {
    EnvironmentEditorView(viewModel: EnvironmentEditorViewModel(
        environment: PreviewContainer.environment(named: "Restaurant")))
        .modelContainer(PreviewContainer.shared)
}
