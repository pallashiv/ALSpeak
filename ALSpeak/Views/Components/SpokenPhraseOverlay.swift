import SwiftUI

/// Full-screen display of the phrase just spoken, so the listener can read it too.
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

    var body: some View {
        ZStack {
            (isEmergency ? Palette.environmentColor("red") : Palette.overlayBackground)
                .ignoresSafeArea()
                .onTapGesture(perform: onClose)
                .accessibilityHidden(true)

            VStack(spacing: 24) {
                Spacer(minLength: 0)
                if isEmergency {
                    Label("EMERGENCY", systemImage: "exclamationmark.triangle.fill")
                        .font(.title.weight(.heavy))
                        .foregroundStyle(Palette.overlayText)
                }
                Text(text)
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Palette.overlayText)
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
            .padding(24)
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape, onClose)
    }

    private func overlayButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.title3.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: controlHeight)
                .foregroundStyle(.black)
                .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
