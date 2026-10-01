import SwiftUI

/// The always-available emergency alert button.
///
/// With `requiresHold`, the user presses and holds for `holdDuration`; a red fill shows
/// progress, and lifting early cancels. Small finger movement (tremor) is tolerated.
/// VoiceOver, Switch Control and Voice Control activate it directly through the
/// accessibility action, because a timed hold is hard or impossible with those.
struct EmergencyButton: View {
    var requiresHold = true
    var holdDuration: Double = 1.0
    /// Smaller variant for sheet toolbars.
    var compact = false
    let action: () -> Void

    @State private var progress: CGFloat = 0
    @ScaledMetric(relativeTo: .headline) private var size: CGFloat = 60

    var body: some View {
        label
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .modifier(ActivationGesture(requiresHold: requiresHold, holdDuration: holdDuration,
                                        progress: $progress, action: action))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Emergency help")
            .accessibilityHint("Speaks your emergency message loudly")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { action() }
            .accessibilityInputLabels(["Emergency", "Help", "Emergency help"])
            .accessibilityShowsLargeContentViewer {
                Image(systemName: "sos")
                Text("Emergency help")
            }
    }

    private var label: some View {
        let shape = RoundedRectangle(cornerRadius: compact ? 12 : 20, style: .continuous)
        return VStack(spacing: 0) {
            Image(systemName: "sos")
                .font(compact ? .body.weight(.bold) : .title3.weight(.heavy))
            if !compact && requiresHold {
                Text("hold")
                    .font(.caption2.weight(.semibold))
                    .opacity(0.9)
            }
        }
        .foregroundStyle(.white)
        .frame(minWidth: compact ? 44 : size, minHeight: compact ? 36 : size)
        .padding(.horizontal, compact ? 8 : 4)
        .background {
            shape.fill(Palette.environmentColor("red"))
            // A lighter band fills from the bottom up while holding.
            GeometryReader { proxy in
                Rectangle()
                    .fill(.white.opacity(0.35))
                    .frame(height: proxy.size.height * progress)
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
            .clipShape(shape)
        }
    }
}

/// A plain tap, or a press-and-hold that reports progress.
private struct ActivationGesture: ViewModifier {
    let requiresHold: Bool
    let holdDuration: Double
    @Binding var progress: CGFloat
    let action: () -> Void

    func body(content: Content) -> some View {
        if requiresHold {
            content.onLongPressGesture(minimumDuration: holdDuration, maximumDistance: 40) {
                action()
            } onPressingChanged: { isPressing in
                withAnimation(isPressing ? .linear(duration: holdDuration) : .easeOut(duration: 0.2)) {
                    progress = isPressing ? 1 : 0
                }
            }
        } else {
            content.onTapGesture(perform: action)
        }
    }
}

#Preview {
    HStack(spacing: 20) {
        EmergencyButton(requiresHold: true) {}
        EmergencyButton(requiresHold: false) {}
        EmergencyButton(compact: true) {}
    }
    .padding()
}
