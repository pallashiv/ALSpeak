import SwiftUI

/// A large, high-contrast button that speaks a phrase.
///
/// Activation follows the user's touch mode (tap, hold or dwell — see `selectable`). In tap
/// mode it's a standard `Button`, which already ignores touches that drag off it or turn
/// into a scroll, so a finger sliding across the grid doesn't speak.
struct PhraseButton: View {
    let text: String
    var tint: Color
    var isFavorite = false
    /// Tokens (e.g. "name") this phrase uses that have no value yet.
    var missingTokens: [String] = []
    /// VoiceOver hint; changes to "Edits this phrase" in edit mode.
    var accessibilityHint = "Speaks this phrase aloud"
    /// In edit mode a plain tap is always used, whatever the touch mode.
    var usesTouchMode = true
    let action: () -> Void

    @Environment(\.appTheme) private var theme
    @ScaledMetric(relativeTo: .title3) private var minHeight: CGFloat = 88

    private static let cornerRadius: CGFloat = 16

    var body: some View {
        Group {
            if usesTouchMode {
                label.selectable(cornerRadius: Self.cornerRadius, action: action)
            } else {
                Button(action: action) { label }
                    .buttonStyle(PressFeedbackButtonStyle())
            }
        }
        .accessibilityLabel(text)
        .accessibilityHint(accessibilityHint)
        .accessibilityValue(isFavorite ? "Favorite" : "")
    }

    private var label: some View {
        let colors = Palette.controlColors(tint: tint, theme: theme)
        return HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(text)
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                if !missingTokens.isEmpty {
                    Label("Set \(missingTokens.map(TokenKey.displayName).joined(separator: ", ").lowercased()) in Settings",
                          systemImage: "exclamationmark.circle")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(colors.accent)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if isFavorite {
                Image(systemName: "star.fill")
                    .font(.body)
                    .foregroundStyle(colors.accent)
                    .accessibilityHidden(true)
            }
        }
        .foregroundStyle(colors.foreground)
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .topLeading)
        .controlBackground(colors, cornerRadius: Self.cornerRadius)
        .contentShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
    }
}

/// Visible press feedback (slight shrink and dim) so the user can see a touch registered.
struct PressFeedbackButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .brightness(configuration.isPressed ? -0.12 : 0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview("Standard") {
    VStack(spacing: 12) {
        PhraseButton(text: "I'd like to order now", tint: Palette.environmentColor("orange")) {}
        PhraseButton(text: "I love you", tint: Palette.pinned, isFavorite: true) {}
        PhraseButton(text: "My name is {name}", tint: Palette.environmentColor("purple"),
                     missingTokens: ["name"]) {}
    }
    .padding()
}

#Preview("High contrast, hold to select") {
    VStack(spacing: 12) {
        PhraseButton(text: "I'd like to order now", tint: Palette.environmentColor("orange")) {}
        PhraseButton(text: "I love you", tint: Palette.pinned, isFavorite: true) {}
        PhraseButton(text: "My name is {name}", tint: Palette.environmentColor("purple"),
                     missingTokens: ["name"]) {}
    }
    .padding()
    .background(.black)
    .environment(\.appTheme, .highContrast)
    .environment(\.selectionStyle, SelectionStyle(mode: .hold, duration: 1))
}
