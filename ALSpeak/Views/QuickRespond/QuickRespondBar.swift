import SwiftUI
import SwiftData

/// Pinned to the bottom of every screen: a keyboard button (type-to-speak), the
/// Quick Respond replies, and the Emergency button. The replies scroll horizontally; the
/// two outer buttons never move.
struct QuickRespondBar: View {
    let onType: () -> Void

    @Query private var settingsRecords: [UserSettings]
    @Environment(SpeechCoordinator.self) private var coordinator
    @Environment(\.appTheme) private var theme

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
        .accessibilityElement(children: .contain)
        // The bar is always on screen; past this size it would crowd out the phrases.
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }

    private func replyButton(_ reply: String) -> some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        let isHighContrast = theme == .highContrast
        return Text(reply)
            .font(.headline)
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .frame(minWidth: buttonHeight, minHeight: buttonHeight)
            .foregroundStyle(isHighContrast ? Color.white : Color(.label))
            .background(isHighContrast ? Color.black : Color(.secondarySystemBackground), in: shape)
            .overlay(shape.strokeBorder(isHighContrast ? Color.white : Color(.separator),
                                        lineWidth: isHighContrast ? Palette.highContrastBorderWidth : 1))
            .contentShape(shape)
            .selectable(cornerRadius: 14) {
                coordinator.speak(text: reply)
            }
            .accessibilityLabel(reply)
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
