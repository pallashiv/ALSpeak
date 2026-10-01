import SwiftUI

/// A large, high-contrast button that speaks a phrase.
///
/// Uses a standard `Button`, which already ignores touches that drag off the button or
/// turn into a scroll, so a tremor or a finger sliding across the grid doesn't speak.
/// Hold-to-select and dwell modes are added in the accessibility phase.
struct PhraseButton: View {
    let text: String
    var tint: Color
    var isFavorite = false
    /// Tokens (e.g. "name") this phrase uses that have no value yet.
    var missingTokens: [String] = []
    /// VoiceOver hint; changes to "Edits this phrase" in edit mode.
    var accessibilityHint = "Speaks this phrase aloud"
    let action: () -> Void

    @ScaledMetric(relativeTo: .title3) private var minHeight: CGFloat = 88

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(text)
                        .font(.title3.weight(.semibold))
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    if !missingTokens.isEmpty {
                        Label("Set \(missingTokens.joined(separator: ", ")) in Settings",
                              systemImage: "exclamationmark.circle")
                            .font(.caption.weight(.medium))
                            .opacity(0.85)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if isFavorite {
                    Image(systemName: "star.fill")
                        .font(.body)
                        .accessibilityHidden(true)
                }
            }
            .foregroundStyle(.white)
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .topLeading)
            .background(tint, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(PressFeedbackButtonStyle())
        .accessibilityLabel(text)
        .accessibilityHint(accessibilityHint)
        .accessibilityValue(isFavorite ? "Favorite" : "")
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

#Preview("Phrase buttons") {
    VStack(spacing: 12) {
        PhraseButton(text: "I'd like to order now", tint: Palette.environmentColor("orange")) {}
        PhraseButton(text: "I love you", tint: Palette.pinned, isFavorite: true) {}
        PhraseButton(text: "My name is {name}", tint: Palette.environmentColor("purple"),
                     missingTokens: ["name"]) {}
    }
    .padding()
}
