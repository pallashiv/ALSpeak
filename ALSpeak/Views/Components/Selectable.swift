import SwiftUI

/// How speaking buttons are activated, set app-wide from `UserSettings` by `RootView`.
struct SelectionStyle: Equatable {
    var mode: TouchMode = .tap
    /// Seconds for hold / dwell modes.
    var duration: Double = 0.8
}

extension EnvironmentValues {
    @Entry var selectionStyle = SelectionStyle()
    @Entry var appTheme: AppTheme = .standard
}

/// Swallows a second activation that comes very soon after the previous one, which is how
/// a tremor typically shows up (a double tap, or two neighbouring buttons in quick succession).
@MainActor
final class ActivationGate {
    static let shared = ActivationGate()

    let interval: TimeInterval
    private var lastActivation: Date?

    init(interval: TimeInterval = 0.4) {
        self.interval = interval
    }

    /// Returns true (and records the time) if an activation at `now` should go through.
    func allow(now: Date = .now) -> Bool {
        if let lastActivation, now.timeIntervalSince(lastActivation) < interval {
            return false
        }
        lastActivation = now
        return true
    }
}

extension View {
    /// Makes the view a speaking control that honours the user's touch mode:
    /// - **tap**: a normal button (drags and scrolls don't trigger it),
    /// - **hold**: press and hold for the set time; a fill shows progress, lifting cancels,
    /// - **dwell**: rest a head/eye/AssistiveTouch pointer on it for the set time (taps also work).
    ///
    /// VoiceOver, Switch Control and Voice Control always activate it immediately.
    func selectable(cornerRadius: CGFloat = 16, action: @escaping () -> Void) -> some View {
        modifier(SelectableModifier(cornerRadius: cornerRadius, action: action))
    }
}

private struct SelectableModifier: ViewModifier {
    let cornerRadius: CGFloat
    let action: () -> Void

    @Environment(\.selectionStyle) private var style
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress: CGFloat = 0
    @State private var dwellTask: Task<Void, Never>?

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    func body(content: Content) -> some View {
        switch style.mode {
        case .tap:
            Button(action: fire) { content }
                .buttonStyle(PressFeedbackButtonStyle())

        case .hold:
            content
                .overlay(progressOverlay)
                .contentShape(shape)
                // An empty tap handler keeps the long press from blocking scroll gestures.
                .onTapGesture {}
                .onLongPressGesture(minimumDuration: style.duration, maximumDistance: 30) {
                    fire()
                } onPressingChanged: { isPressing in
                    animateProgress(to: isPressing ? 1 : 0)
                }
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { fire() }

        case .dwell:
            Button(action: fire) { content.overlay(progressOverlay) }
                .buttonStyle(PressFeedbackButtonStyle())
                .onContinuousHover { phase in
                    switch phase {
                    case .active: startDwell()
                    case .ended: cancelDwell()
                    }
                }
        }
    }

    /// A lighter band that fills from the leading edge while holding / dwelling.
    private var progressOverlay: some View {
        GeometryReader { proxy in
            Rectangle()
                .fill(.white.opacity(0.35))
                .frame(width: proxy.size.width * progress)
        }
        .clipShape(shape)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func fire() {
        guard ActivationGate.shared.allow() else { return }
        action()
    }

    private func animateProgress(to value: CGFloat) {
        let filling = value > 0
        withAnimation(filling ? .linear(duration: style.duration) : .easeOut(duration: 0.15)) {
            progress = value
        }
    }

    private func startDwell() {
        guard dwellTask == nil else { return }
        animateProgress(to: 1)
        dwellTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .seconds(style.duration))
            } catch {
                return
            }
            fire()
            dwellTask = nil
            animateProgress(to: 0)
        }
    }

    private func cancelDwell() {
        dwellTask?.cancel()
        dwellTask = nil
        animateProgress(to: 0)
    }
}
