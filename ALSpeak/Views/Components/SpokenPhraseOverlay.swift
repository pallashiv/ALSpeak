import SwiftUI

/// Full-screen display of the phrase just spoken, so the listener can read it too:
/// calm and light normally, red for emergencies.
/// Tapping anywhere closes it; it also closes on its own after speech ends.
struct SpokenPhraseOverlay: View {
    let text: String
    let isSpeaking: Bool
    /// Emergency alerts use a red background.
    var isEmergency = false
    let onRepeat: () -> Void
    let onStop: () -> Void
    let onClose: () -> Void

    @ScaledMetric(relativeTo: .body) private var controlHeight: CGFloat = 64
    /// Very large for the listener, and still growing with Dynamic Type.
    @ScaledMetric(relativeTo: .largeTitle) private var phraseSize: CGFloat = 56

    /// Text color: white on the red emergency screen, otherwise the normal text color.
    private var textColor: Color { isEmergency ? .white : Palette.overlayText }

    var body: some View {
        ZStack {
            (isEmergency ? Palette.environmentColor("red") : Palette.overlayBackground)
                .ignoresSafeArea()
                .onTapGesture(perform: onClose)
                .accessibilityHidden(true)

            VStack(spacing: 24) {
                Spacer(minLength: 0)
                if isEmergency {
                    Label("Emergency", systemImage: "sos")
                        .font(.title.weight(.heavy))
                } else {
                    Image(systemName: isSpeaking ? "speaker.wave.3.fill" : "speaker.wave.2")
                        .font(.title)
                        .foregroundStyle(Palette.accent("blue"))
                        .symbolEffect(.variableColor.iterative, isActive: isSpeaking)
                        .accessibilityHidden(true)
                }
                Text(text)
                    .font(.system(size: phraseSize, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.3)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)

                HStack(spacing: 12) {
                    overlayButton(isSpeaking ? "Stop" : "Say again",
                                  systemImage: isSpeaking ? "stop.fill" : "arrow.counterclockwise",
                                  action: isSpeaking ? onStop : onRepeat)
                    overlayButton("Close", systemImage: "xmark", action: onClose)
                }
            }
            .foregroundStyle(textColor)
            .padding(24)
        }
        // Not modal: VoiceOver users have just heard the phrase, so focus stays on the
        // board and they can go straight on to the next phrase. Escape (two-finger
        // scrub) closes it.
        .accessibilityElement(children: .contain)
        .accessibilityAction(.escape, onClose)
    }

    private func overlayButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.title3.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: controlHeight)
                .foregroundStyle(isEmergency ? Color.black : .primary)
                .background(isEmergency ? Color.white : Palette.surface,
                            in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay {
                    if !isEmergency {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(Palette.hairline, lineWidth: 1)
                    }
                }
        }
        .buttonStyle(PressFeedbackButtonStyle())
    }
}

#Preview("Phrase") {
    SpokenPhraseOverlay(text: "Could you check the bill, please?", isSpeaking: true,
                        onRepeat: {}, onStop: {}, onClose: {})
}

#Preview("Emergency") {
    SpokenPhraseOverlay(text: "I need help, please come here now.", isSpeaking: false, isEmergency: true,
                        onRepeat: {}, onStop: {}, onClose: {})
}
