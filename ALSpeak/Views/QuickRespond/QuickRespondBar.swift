import SwiftUI
import SwiftData

/// Pinned to the bottom of every screen: a keyboard button (type-to-speak), the
/// Quick Respond replies, and the Emergency button. The replies scroll horizontally; the
/// two outer buttons never move.
struct QuickRespondBar: View {
    let onType: () -> Void

    @Query private var settingsRecords: [UserSettings]
    @Environment(SpeechCoordinator.self) private var coordinator

    @ScaledMetric(relativeTo: .headline) private var buttonHeight: CGFloat = 64

    private var settings: UserSettings? { settingsRecords.first }

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onType) {
                Image(systemName: "keyboard")
                    .font(.title2)
                    .frame(width: buttonHeight, height: buttonHeight)
                    .foregroundStyle(.white)
                    .background(Palette.pinned, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(PressFeedbackButtonStyle())
            .accessibilityLabel("Type to speak")
            .accessibilityInputLabels(["Type", "Keyboard", "Type to speak"])

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array((settings?.quickResponses ?? []).enumerated()), id: \.offset) { _, reply in
                        replyButton(reply)
                    }
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Quick replies")

            EmergencyButton(requiresHold: settings?.emergencyRequiresHold ?? true) {
                coordinator.speakEmergency()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar, ignoresSafeAreaEdges: .bottom)
        .overlay(alignment: .top) { Divider() }
    }

    private func replyButton(_ reply: String) -> some View {
        Button {
            coordinator.speak(text: reply)
        } label: {
            Text(reply)
                .font(.headline)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .frame(minWidth: buttonHeight, minHeight: buttonHeight)
                .foregroundStyle(Color(.label))
                .background(Color(.secondarySystemBackground),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color(.separator), lineWidth: 1))
        }
        .buttonStyle(PressFeedbackButtonStyle())
        .accessibilityHint("Speaks this reply")
    }
}

#Preview {
    VStack {
        Spacer()
        QuickRespondBar(onType: {})
    }
    .modelContainer(PreviewContainer.shared)
    .environment(PreviewContainer.coordinator)
}
