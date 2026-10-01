import SwiftUI
import SwiftData

/// Voice, personal details, emergency alert and quick replies.
/// Edits write straight to `UserSettings` and take effect on the next spoken phrase.
struct SettingsView: View {
    @Bindable var settings: UserSettings

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(SpeechCoordinator.self) private var coordinator
    @State private var viewModel = SettingsViewModel()

    // Add/edit prompts
    @State private var isAddingDetail = false
    @State private var newDetailLabel = ""
    @State private var replyEditor: ReplyDraft?

    struct ReplyDraft: Identifiable {
        let id = UUID()
        /// nil when adding a new reply.
        let index: Int?
        var text: String
    }

    var body: some View {
        NavigationStack {
            Form {
                voiceSection
                personalDetailsSection
                emergencySection
                quickRepliesSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EmergencyButton(requiresHold: settings.emergencyRequiresHold, compact: true) {
                        coordinator.speakEmergency()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        try? context.save()
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
            .alert("Add a personal detail", isPresented: $isAddingDetail) {
                TextField("For example: Pet's name", text: $newDetailLabel)
                Button("Add") { addDetail() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You can then use it in any phrase.")
            }
            .alert(replyEditor?.index == nil ? "Add a quick reply" : "Edit quick reply",
                   isPresented: Binding(get: { replyEditor != nil }, set: { if !$0 { replyEditor = nil } }),
                   presenting: replyEditor) { draft in
                TextField("Reply", text: Binding(
                    get: { replyEditor?.text ?? draft.text },
                    set: { replyEditor?.text = $0 }
                ))
                Button("Save") { saveReply() }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    // MARK: Voice

    private var voiceSection: some View {
        Section {
            NavigationLink {
                VoicePickerView(settings: settings, viewModel: viewModel)
            } label: {
                LabeledContent("Voice", value: viewModel.voiceName(for: settings.voiceIdentifier))
                    .frame(minHeight: 44)
            }

            AdjustableRow(title: "Speed", value: $settings.speechRate, range: SettingsViewModel.rateRange,
                          step: 0.05, valueLabel: SettingsViewModel.rateLabel)
            AdjustableRow(title: "Pitch", value: $settings.pitch, range: SettingsViewModel.pitchRange,
                          step: 0.1, valueLabel: { String(format: "%.1f", $0) })
            AdjustableRow(title: "Volume", value: $settings.volume, range: SettingsViewModel.volumeRange,
                          step: 0.1, valueLabel: { "\(Int(($0 * 100).rounded()))%" })

            Button {
                coordinator.preview(text: SettingsViewModel.sampleSentence)
            } label: {
                Label("Test voice", systemImage: "play.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
        } header: {
            Text("Voice")
        } footer: {
            Text("Speech plays even when the phone is on silent. The phone's own volume buttons still set the overall loudness.")
        }
    }

    // MARK: Personal details

    private var personalDetailsSection: some View {
        Section {
            ForEach(settings.tokens.keys.sorted(), id: \.self) { key in
                VStack(alignment: .leading, spacing: 4) {
                    Text(TokenKey.displayName(for: key))
                        .font(.subheadline.weight(.semibold))
                    TextField(TokenKey.displayName(for: key), text: tokenBinding(key))
                        .font(.title3)
                    Text("Use in phrases as {\(key)}")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
            .onDelete { offsets in
                let keys = settings.tokens.keys.sorted()
                offsets.forEach { settings.tokens.removeValue(forKey: keys[$0]) }
            }

            Button {
                newDetailLabel = ""
                isAddingDetail = true
            } label: {
                Label("Add a personal detail", systemImage: "plus.circle.fill")
                    .frame(minHeight: 44)
            }
        } header: {
            Text("Personal details")
        } footer: {
            Text("Phrases like “My name is {name}” fill these in when spoken.")
        }
    }

    private func tokenBinding(_ key: String) -> Binding<String> {
        Binding(
            get: { settings.tokens[key] ?? "" },
            set: { settings.tokens[key] = $0 }
        )
    }

    private func addDetail() {
        guard let key = TokenKey.make(from: newDetailLabel), settings.tokens[key] == nil else { return }
        settings.tokens[key] = ""
    }

    // MARK: Emergency

    private var emergencySection: some View {
        Section {
            TextField("Emergency message", text: $settings.emergencyPhrase, axis: .vertical)
                .font(.title3)
                .lineLimit(2...5)
            Stepper("Repeat \(settings.emergencyRepeatCount) \(settings.emergencyRepeatCount == 1 ? "time" : "times")",
                    value: $settings.emergencyRepeatCount, in: 1...5)
                .frame(minHeight: 44)
            Toggle("Hold to activate", isOn: $settings.emergencyRequiresHold)
                .frame(minHeight: 44)
            Button(role: .destructive) {
                coordinator.speakEmergency()
            } label: {
                Label("Test emergency alert (loud)", systemImage: "speaker.wave.3.fill")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
        } header: {
            Text("Emergency button")
        } footer: {
            Text("Holding for one second prevents accidental alarms. VoiceOver and Switch Control users can always activate it directly.")
        }
    }

    // MARK: Quick replies

    private var quickRepliesSection: some View {
        Section {
            ForEach(Array(settings.quickResponses.enumerated()), id: \.offset) { index, reply in
                Button {
                    replyEditor = ReplyDraft(index: index, text: reply)
                } label: {
                    Text(reply)
                        .foregroundStyle(Color.primary)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
            }
            .onMove { settings.quickResponses = Reorder.moved(settings.quickResponses, from: $0, to: $1) }
            .onDelete { settings.quickResponses.remove(atOffsets: $0) }

            Button {
                replyEditor = ReplyDraft(index: nil, text: "")
            } label: {
                Label("Add a quick reply", systemImage: "plus.circle.fill")
                    .frame(minHeight: 44)
            }
        } header: {
            HStack {
                Text("Quick replies")
                Spacer()
                EditButton()
                    .font(.subheadline.weight(.semibold))
                    .textCase(nil)
            }
        } footer: {
            Text("Shown at the bottom of every screen. Tap Edit to reorder.")
        }
    }

    private func saveReply() {
        guard let draft = replyEditor else { return }
        let text = draft.text.trimmed
        guard !text.isEmpty else { return }
        if let index = draft.index, settings.quickResponses.indices.contains(index) {
            settings.quickResponses[index] = text
        } else {
            settings.quickResponses.append(text)
        }
    }
}

/// Slider with large − / + buttons on each side, so the value can be changed in exact
/// steps without the fine finger control a slider needs.
struct AdjustableRow: View {
    let title: String
    @Binding var value: Float
    let range: ClosedRange<Float>
    let step: Float
    let valueLabel: (Float) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            LabeledContent(title, value: valueLabel(value))
                .font(.headline)
            HStack(spacing: 12) {
                stepButton("minus", label: "Decrease \(title.lowercased())", delta: -step)
                Slider(value: $value, in: range, step: step)
                    .accessibilityLabel(title)
                    .accessibilityValue(valueLabel(value))
                stepButton("plus", label: "Increase \(title.lowercased())", delta: step)
            }
        }
        .padding(.vertical, 6)
    }

    private func stepButton(_ symbol: String, label: String, delta: Float) -> some View {
        Button {
            value = (value + delta).clamped(to: range)
        } label: {
            Image(systemName: symbol)
                .font(.title3.weight(.bold))
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel(label)
    }
}

#Preview {
    SettingsView(settings: UserSettings.current(in: PreviewContainer.shared.mainContext))
        .modelContainer(PreviewContainer.shared)
        .environment(PreviewContainer.coordinator)
}
