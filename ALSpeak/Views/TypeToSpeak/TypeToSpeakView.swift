import SwiftUI
import SwiftData

/// Fallback typing for when no preset phrase fits: type, speak, and optionally save the
/// text as a phrase with one tap. Shows suggestions while typing and recent texts.
struct TypeToSpeakView: View {
    /// The place the user was on when they opened this screen; nil from the home screen.
    let currentEnvironment: SpeakEnvironment?

    @Query private var phrases: [Phrase]
    @Query(sort: \SpeakEnvironment.sortOrder) private var environments: [SpeakEnvironment]
    @Query private var settingsRecords: [UserSettings]

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(SpeechCoordinator.self) private var coordinator

    @State private var viewModel = TypeToSpeakViewModel()
    @State private var savedMessage: String?
    @FocusState private var isFieldFocused: Bool

    @ScaledMetric(relativeTo: .title3) private var actionHeight: CGFloat = 64

    private var settings: UserSettings { settingsRecords.first ?? UserSettings.current(in: context) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    TextField("Type what you want to say", text: $viewModel.text, axis: .vertical)
                        .font(.title2.weight(.semibold))
                        .lineLimit(3...6)
                        .focused($isFieldFocused)
                        .submitLabel(.done)
                        .padding(16)
                        .background(Color(.secondarySystemBackground),
                                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .accessibilityLabel("Text to speak")

                    actionButtons

                    if let savedMessage {
                        Label(savedMessage, systemImage: "checkmark.circle.fill")
                            .font(.headline)
                            .foregroundStyle(.green)
                    }

                    let suggestions = viewModel.suggestions(
                        phrases: phrases, recents: settings.recentTypedTexts, tokens: settings.tokens)
                    if !suggestions.isEmpty {
                        listSection("Suggestions", items: suggestions.map { ($0.text, $0.phrase) })
                    }

                    if !settings.recentTypedTexts.isEmpty {
                        listSection("Recent", items: settings.recentTypedTexts.map { ($0, nil) })
                    }
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Type to Speak")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    EmergencyButton(requiresHold: settings.emergencyRequiresHold, compact: true) {
                        coordinator.speakEmergency()
                    }
                }
            }
            .onAppear { isFieldFocused = true }
            .onChange(of: viewModel.text) { savedMessage = nil }
        }
    }

    // MARK: Buttons

    private var actionButtons: some View {
        HStack(spacing: 10) {
            Button {
                coordinator.speak(text: viewModel.trimmedText, showOverlay: false)
                viewModel.recordSpoken(in: settings)
            } label: {
                Label("Speak", systemImage: "speaker.wave.2.fill")
                    .font(.title3.weight(.bold))
                    .frame(maxWidth: .infinity, minHeight: actionHeight)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canSpeak)

            saveButton

            Button {
                viewModel.text = ""
                isFieldFocused = true
            } label: {
                Image(systemName: "xmark")
                    .font(.title3.weight(.bold))
                    .frame(minWidth: 44, minHeight: actionHeight)
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.text.isEmpty)
            .accessibilityLabel("Clear")
        }
    }

    /// One tap saves to the current place; from the home screen a menu asks which place.
    @ViewBuilder
    private var saveButton: some View {
        let label = Label("Save", systemImage: "square.and.arrow.down")
            .font(.title3.weight(.semibold))
            .frame(minWidth: 44, minHeight: actionHeight)

        if let currentEnvironment {
            Button {
                save(to: currentEnvironment)
            } label: { label }
            .buttonStyle(.bordered)
            .disabled(!viewModel.canSpeak)
            .accessibilityLabel("Save to \(currentEnvironment.name)")
        } else {
            Menu {
                ForEach(environments.filter { !$0.isHidden }) { environment in
                    Button(environment.name) { save(to: environment) }
                }
            } label: { label }
            .buttonStyle(.bordered)
            .disabled(!viewModel.canSpeak)
            .accessibilityLabel("Save as a phrase")
        }
    }

    private func save(to environment: SpeakEnvironment) {
        guard viewModel.save(to: environment, using: PhraseLibraryEditor(context: context)) != nil else { return }
        savedMessage = "Saved to \(environment.name) → \(TypeToSpeakViewModel.savedCategoryName)"
    }

    // MARK: Lists

    private func listSection(_ title: String, items: [(text: String, phrase: Phrase?)]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.title3.weight(.bold))
                .accessibilityAddTraits(.isHeader)
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                PhraseButton(text: item.text, tint: Palette.pinned) {
                    if let phrase = item.phrase {
                        coordinator.speak(phrase, showOverlay: false)
                    } else {
                        coordinator.speak(text: item.text, showOverlay: false)
                    }
                }
            }
        }
    }
}

#Preview("From home") {
    TypeToSpeakView(currentEnvironment: nil)
        .modelContainer(PreviewContainer.shared)
        .environment(PreviewContainer.coordinator)
}

#Preview("From Restaurant") {
    TypeToSpeakView(currentEnvironment: PreviewContainer.environment(named: "Restaurant"))
        .modelContainer(PreviewContainer.shared)
        .environment(PreviewContainer.coordinator)
}
