import SwiftUI
import SwiftData

/// Pinned to the bottom of every screen: a keyboard button (type-to-speak), the
/// Quick Respond replies, and the Emergency button. The replies scroll sideways; the
/// two outer buttons never move.
///
/// "Yes" and "No" get soft green / red with a ✓ / ✕, so they can be found at a glance.
struct QuickRespondBar: View {
    let onType: () -> Void

    @Query private var settingsRecords: [UserSettings]
    @Environment(SpeechCoordinator.self) private var coordinator
    @Environment(\.appTheme) private var theme

    @ScaledMetric(relativeTo: .headline) private var buttonHeight: CGFloat = 60

    private var settings: UserSettings? { settingsRecords.first }
    private var isHighContrast: Bool { theme == .highContrast }

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onType) {
                Image(systemName: "keyboard")
                    .font(.title2)
                    .foregroundStyle(isHighContrast ? Color.white : .primary)
                    .frame(width: buttonHeight, height: buttonHeight)
                    .background(isHighContrast ? Color.black : Palette.soft("gray"), in: Circle())
                    .overlay {
                        if isHighContrast {
                            Circle().strokeBorder(Color.white, lineWidth: Palette.highContrastBorderWidth)
                        }
                    }
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
                .padding(.vertical, 2)
                .padding(.trailing, 24)
            }
            // Fade the trailing edge so a cut-off reply reads as "scroll for more".
            .mask(
                HStack(spacing: 0) {
                    Color.black
                    LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                        .frame(width: 28)
                }
            )
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Quick replies")

            EmergencyButton(requiresHold: settings?.emergencyRequiresHold ?? true) {
                coordinator.speakEmergency()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Palette.surface, ignoresSafeAreaEdges: .bottom)
        .overlay(alignment: .top) {
            Rectangle().fill(Palette.hairline).frame(height: 1)
        }
        .accessibilityElement(children: .contain)
        // The bar is always on screen; past this size it would crowd out the phrases.
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }

    /// Color key and icon for well-known replies.
    private static func style(for reply: String) -> (colorKey: String, symbol: String?) {
        switch reply.trimmed.lowercased() {
        case "yes": ("green", "checkmark")
        case "no": ("red", "xmark")
        default: ("gray", nil)
        }
    }

    private func replyButton(_ reply: String) -> some View {
        let style = Self.style(for: reply)
        let shape = Capsule()
        return HStack(spacing: 6) {
            if let symbol = style.symbol {
                Image(systemName: symbol)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(isHighContrast ? Palette.highContrastAccent : Palette.accent(style.colorKey))
            }
            Text(reply)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .font(.headline)
        .padding(.horizontal, 20)
        .frame(minWidth: buttonHeight, minHeight: buttonHeight)
        .foregroundStyle(isHighContrast ? Color.white : .primary)
        .background(isHighContrast ? Color.black : Palette.soft(style.colorKey), in: shape)
        .overlay {
            if isHighContrast {
                shape.strokeBorder(Color.white, lineWidth: Palette.highContrastBorderWidth)
            }
        }
        .contentShape(shape)
        .selectable(cornerRadius: buttonHeight / 2) {
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
    .background(Palette.background)
    .modelContainer(PreviewContainer.shared)
    .environment(PreviewContainer.coordinator)
    .fontDesign(.rounded)
}
