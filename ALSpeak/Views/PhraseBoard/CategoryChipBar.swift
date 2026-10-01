import SwiftUI

/// Big, rounded tabs ("Favorites", "Ordering", "Needs"…) that wrap onto extra rows rather
/// than scrolling sideways, so every category is always visible. The selected tab is filled
/// with the place's color; the others are plain white.
struct CategoryChipBar: View {
    let tabs: [PhraseBoardViewModel.Tab]
    let selected: PhraseBoardViewModel.Filter?
    let colorKey: String
    let onSelect: (PhraseBoardViewModel.Filter) -> Void

    @Environment(\.appTheme) private var theme
    /// Fixed minimum (not scaled): at large text sizes the text itself makes the tab taller.
    private let tabHeight: CGFloat = 56

    var body: some View {
        FlowLayout(spacing: 10) {
            ForEach(tabs) { tab in
                tabButton(tab)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Categories")
        // Tabs grow with Dynamic Type, but stop before they push the phrases off screen.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    private func tabButton(_ tab: PhraseBoardViewModel.Tab) -> some View {
        let isSelected = tab.filter == selected
        let isFavorites = tab.filter == .favorites
        let isHighContrast = theme == .highContrast
        let fill: Color = isHighContrast
            ? (isSelected ? Palette.highContrastAccent : .black)
            : (isSelected ? Palette.environmentColor(colorKey) : Palette.surface)
        let text: Color = isHighContrast
            ? (isSelected ? .black : .white)
            : (isSelected ? .white : .primary)

        return Button {
            onSelect(tab.filter)
        } label: {
            HStack(spacing: 6) {
                if isFavorites {
                    Image(systemName: "star.fill")
                        .foregroundStyle(isSelected ? text : Palette.accent(Palette.favoriteKey))
                }
                Text(tab.title)
            }
            .font(.headline)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .frame(minWidth: 72, minHeight: tabHeight)
            .foregroundStyle(text)
            .background(fill, in: Capsule())
            .overlay {
                if isHighContrast {
                    Capsule().strokeBorder(Palette.highContrastAccent, lineWidth: Palette.highContrastBorderWidth)
                } else if !isSelected {
                    Capsule().strokeBorder(Palette.hairline, lineWidth: 1)
                }
            }
        }
        .buttonStyle(PressFeedbackButtonStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
