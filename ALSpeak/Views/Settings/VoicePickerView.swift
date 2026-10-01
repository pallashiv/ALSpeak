import SwiftUI
import AVFoundation

/// Pick a voice. Tapping a row selects it and plays a sample.
struct VoicePickerView: View {
    @Bindable var settings: UserSettings
    let viewModel: SettingsViewModel

    @Environment(SpeechCoordinator.self) private var coordinator

    var body: some View {
        List {
            Section {
                personalVoiceRow
            } footer: {
                Text("If you've recorded a Personal Voice (iOS Settings → Accessibility → Personal Voice), ALSpeak can speak with it.")
            }

            Section {
                voiceRow(id: nil, name: "System default", detail: nil)
                ForEach(viewModel.voices) { voice in
                    voiceRow(
                        id: voice.id,
                        name: voice.name,
                        detail: [voice.isPersonalVoice ? "Personal Voice" : nil, voice.quality.label, voice.languageName]
                            .compactMap { $0 }
                            .joined(separator: " · ")
                    )
                }
            } header: {
                Text("Voices")
            } footer: {
                Text("Download higher-quality voices in iOS Settings → Accessibility → Spoken Content → Voices.")
            }
        }
        .navigationTitle("Voice")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { viewModel.reloadVoices() }
    }

    @ViewBuilder
    private var personalVoiceRow: some View {
        switch viewModel.personalVoiceStatus {
        case .authorized:
            Label("Personal Voice is allowed", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .denied:
            Label("Personal Voice access was denied. Allow it in iOS Settings → ALSpeak.",
                  systemImage: "xmark.circle")
        case .unsupported:
            Label("Personal Voice isn't available on this device.", systemImage: "info.circle")
        default:
            Button {
                viewModel.requestPersonalVoice()
            } label: {
                Label("Use my Personal Voice", systemImage: "person.wave.2.fill")
                    .font(.headline)
                    .frame(minHeight: 44)
            }
        }
    }

    private func voiceRow(id: String?, name: String, detail: String?) -> some View {
        let isSelected = settings.voiceIdentifier == id
        return Button {
            settings.voiceIdentifier = id
            coordinator.preview(text: SettingsViewModel.sampleSentence)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.headline)
                        .foregroundStyle(Color.primary)
                    if let detail, !detail.isEmpty {
                        Text(detail)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.headline)
                        .foregroundStyle(Color.accentColor)
                }
            }
            .frame(minHeight: 44)
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint("Selects this voice and plays a sample")
    }
}

#Preview {
    NavigationStack {
        VoicePickerView(settings: UserSettings.current(in: PreviewContainer.shared.mainContext),
                        viewModel: SettingsViewModel())
    }
    .environment(PreviewContainer.coordinator)
}
