import SwiftUI
import SwiftData

/// Splits the quick replies into the ones always on the bar and the ones under "More".
enum QuickRespondLayout {
    /// How many replies sit directly on the bar (big enough to hit easily on a phone).
    static let inlineCount = 2

    static func split(_ replies: [String], inlineCount: Int = inlineCount) -> (inline: [String], more: [String]) {
        (Array(replies.prefix(inlineCount)), Array(replies.dropFirst(inlineCount)))
    }
}

/// Pinned to the bottom of every screen, with no scrolling:
///
///     ┌──────────────────────────────────────┐
///     │  Maybe          Thank you            │  ← "More" panel (when open):
///     │  Wait a moment  Could you repeat…    │    every other reply + typing
///     │  ⌨︎ Type a message                    │
///     ├──────────────────────────────────────┤
///     │ [✓ Yes] [✕ No] [••• More]  │  [SOS]  │  ← always visible
///     └──────────────────────────────────────┘
///
/// The first two quick replies (Yes / No by default) are always on the bar; "Yes" and "No"
/// get soft green / red with a ✓ / ✕ so they can be found at a glance. The panel closes
/// by itself after a reply is spoken.
struct QuickRespondBar: View {
    let onType: () -> Void

    @Query private var settingsRecords: [UserSettings]
    @Environment(SpeechCoordinator.self) private var coordinator
    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    #if DEBUG
    /// `-ExpandMore` opens the panel on launch (for screenshots).
    @State private var isExpanded = ProcessInfo.processInfo.arguments.contains("-ExpandMore")
    #else
    @State private var isExpanded = false
    #endif

    @ScaledMetric(relativeTo: .headline) private var buttonHeight: CGFloat = 60
    @ScaledMetric(relativeTo: .headline) private var panelMinWidth: CGFloat = 150

    private var settings: UserSettings? { settingsRecords.first }
    private var isHighContrast: Bool { theme == .highContrast }
    private var replies: (inline: [String], more: [String]) {
        QuickRespondLayout.split(settings?.quickResponses ?? [])
    }

    var body: some View {
        VStack(spacing: 0) {
            if isExpanded {
                morePanel
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            }
            bar
        }
        .background(Palette.surface, ignoresSafeAreaEdges: .bottom)
        .overlay(alignment: .top) {
            Rectangle().fill(Palette.hairline).frame(height: 1)
        }
        .accessibilityElement(children: .contain)
        // Note: RootView caps this bar's Dynamic Type size (see there).
    }

    // MARK: Bar

    private var bar: some View {
        HStack(spacing: 8) {
            ForEach(Array(replies.inline.enumerated()), id: \.offset) { _, reply in
                replyButton(reply)
            }
            moreButton

            // Keep SOS clearly apart from the replies, so reaching for "No" can't land on it.
            Rectangle()
                .fill(Palette.hairline)
                .frame(width: 1, height: buttonHeight * 0.6)
                .padding(.horizontal, 6)
                .accessibilityHidden(true)

            EmergencyButton(requiresHold: settings?.emergencyRequiresHold ?? true) {
                setExpanded(false)
                coordinator.speakEmergency()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var moreButton: some View {
        Button {
            setExpanded(!isExpanded)
        } label: {
            VStack(spacing: 2) {
                Image(systemName: isExpanded ? "chevron.down" : "ellipsis")
                    .font(.headline.weight(.bold))
                    .frame(height: 20)
                Text(isExpanded ? "Close" : "More")
                    .font(.subheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity, minHeight: buttonHeight)
            .foregroundStyle(isExpanded || isHighContrast ? Color.white : Color.primary)
            .background(moreButtonFill, in: Capsule())
            .overlay {
                if isHighContrast {
                    Capsule().strokeBorder(Color.white, lineWidth: Palette.highContrastBorderWidth)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(PressFeedbackButtonStyle())
        .accessibilityShowsLargeContentViewer {
            Image(systemName: "ellipsis")
            Text(isExpanded ? "Close" : "More")
        }
        .accessibilityLabel(isExpanded ? "Close more replies" : "More replies")
        .accessibilityHint(isExpanded ? "" : "Shows all quick replies and typing")
        .accessibilityInputLabels(["More", "More replies"])
    }

    private var moreButtonFill: Color {
        if isHighContrast { return .black }
        return isExpanded ? Palette.environmentColor("gray") : Palette.soft("gray")
    }

    // MARK: More panel

    private var morePanel: some View {
        VStack(spacing: 10) {
            if !replies.more.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: panelMinWidth), spacing: 10)], spacing: 10) {
                    ForEach(Array(replies.more.enumerated()), id: \.offset) { _, reply in
                        replyButton(reply, fillsWidth: true)
                    }
                }
            }

            Button {
                setExpanded(false)
                onType()
            } label: {
                Label("Type a message", systemImage: "keyboard")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: buttonHeight)
                    .foregroundStyle(isHighContrast ? Color.white : .primary)
                    .background(isHighContrast ? Color.black : Palette.background,
                                in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(isHighContrast ? Color.white : Palette.hairline,
                                          lineWidth: isHighContrast ? Palette.highContrastBorderWidth : 1)
                    }
            }
            .buttonStyle(PressFeedbackButtonStyle())
            .accessibilityInputLabels(["Type", "Keyboard", "Type a message"])
        }
        .padding(.horizontal, 12)
        .padding(.top, 14)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("More replies")
    }

    // MARK: Reply buttons

    /// Color key and icon for well-known replies.
    private static func style(for reply: String) -> (colorKey: String, symbol: String?) {
        switch reply.trimmed.lowercased() {
        case "yes": ("green", "checkmark")
        case "no": ("red", "xmark")
        default: ("gray", nil)
        }
    }

    /// - Parameter fillsWidth: In the panel, replies are grid cells with rounded corners.
    private func replyButton(_ reply: String, fillsWidth: Bool = false) -> some View {
        let style = Self.style(for: reply)
        let cornerRadius: CGFloat = fillsWidth ? 18 : buttonHeight / 2
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let icon = style.symbol.map {
            Image(systemName: $0)
                .font(.headline.weight(.bold))
                .foregroundStyle(isHighContrast ? Palette.highContrastAccent : Palette.accent(style.colorKey))
        }
        let text = Text(reply)
            .lineLimit(fillsWidth ? 2 : 1)
            .multilineTextAlignment(.center)
        // With big text the label might not fit: fall back to the text alone, then to the
        // ✓ / ✕ alone, rather than truncating ("Y…") or wrapping into a sliver.
        // `fixedSize` keeps each candidate at its full width, so ViewThatFits picks one
        // that really fits instead of squeezing the text by a fraction of a point.
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) { icon; text }.fixedSize()
            text.fixedSize()
            if let icon { icon } else { text.minimumScaleFactor(0.6) }
        }
        .font(.headline)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: buttonHeight)
        .foregroundStyle(isHighContrast ? Color.white : .primary)
        .background(isHighContrast ? Color.black : Palette.soft(style.colorKey), in: shape)
        .overlay {
            if isHighContrast {
                shape.strokeBorder(Color.white, lineWidth: Palette.highContrastBorderWidth)
            }
        }
        .contentShape(shape)
        .selectable(cornerRadius: cornerRadius) {
            coordinator.speak(text: reply)
            setExpanded(false)
        }
        .accessibilityLabel(reply)
        .accessibilityHint("Speaks this reply")
        .accessibilityRemoveTraits(.isSelected)
        .accessibilityShowsLargeContentViewer {
            if let symbol = style.symbol { Image(systemName: symbol) }
            Text(reply)
        }
    }

    private func setExpanded(_ expanded: Bool) {
        withAnimation(reduceMotion ? nil : .spring(duration: 0.3)) {
            isExpanded = expanded
        }
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
