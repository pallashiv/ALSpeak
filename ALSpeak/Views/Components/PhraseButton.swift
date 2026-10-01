import SwiftUI

/// A large, calm button that speaks a phrase: dark text on a soft tint of the place's color.
///
/// Activation follows the user's touch mode (tap, hold or dwell — see `selectable`). In tap
/// mode it's a standard `Button`, which already ignores touches that drag off it or turn
/// into a scroll, so a finger sliding across the grid doesn't speak.
struct PhraseButton: View {
    let text: String
    /// Palette key ("blue", "gold"…) that tints the button.
    var colorKey: String
    var isFavorite = false
    /// Tokens (e.g. "name") this phrase uses that have no value yet.
    var missingTokens: [String] = []
    /// VoiceOver hint; changes to "Edits this phrase" in edit mode.
    var accessibilityHint = "Speaks this phrase aloud"
    /// In edit mode a plain tap is always used, whatever the touch mode.
    var usesTouchMode = true
    let action: () -> Void

    @Environment(\.appTheme) private var theme
    @ScaledMetric(relativeTo: .title3) private var minHeight: CGFloat = 96

    static let cornerRadius: CGFloat = 22

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
        let colors = Palette.controlColors(colorKey: colorKey, theme: theme)
        return VStack(alignment: .leading, spacing: 6) {
            Text(text)
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            if !missingTokens.isEmpty {
                Label("Add \(missingTokens.map(TokenKey.displayName).joined(separator: ", ").lowercased()) in Settings",
                      systemImage: "info.circle")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(colors.accent)
            }
        }
        .foregroundStyle(colors.foreground)
        .padding(18)
        // Fills the row height in a grid so neighbouring cards line up.
        .frame(maxWidth: .infinity, minHeight: minHeight, maxHeight: .infinity, alignment: .topLeading)
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
            .brightness(configuration.isPressed ? -0.06 : 0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview("Standard") {
    VStack(spacing: 12) {
        PhraseButton(text: "I'd like to order now", colorKey: "orange") {}
        PhraseButton(text: "I love you", colorKey: Palette.favoriteKey, isFavorite: true) {}
        PhraseButton(text: "My name is {name}", colorKey: "purple", missingTokens: ["name"]) {}
    }
    .padding()
    .background(Palette.background)
    .fontDesign(.rounded)
}

#Preview("High contrast, hold to select") {
    VStack(spacing: 12) {
        PhraseButton(text: "I'd like to order now", colorKey: "orange") {}
        PhraseButton(text: "I love you", colorKey: Palette.favoriteKey, isFavorite: true) {}
        PhraseButton(text: "My name is {name}", colorKey: "purple", missingTokens: ["name"]) {}
    }
    .padding()
    .background(.black)
    .environment(\.appTheme, .highContrast)
    .environment(\.selectionStyle, SelectionStyle(mode: .hold, duration: 1))
}
