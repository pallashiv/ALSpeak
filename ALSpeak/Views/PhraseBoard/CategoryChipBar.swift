import SwiftUI

/// Row of big, rounded tabs ("Favorites", "Ordering", "Needs"…). The selected tab is filled
/// with the place's color; the others are plain white.
struct CategoryChipBar: View {
    let tabs: [PhraseBoardViewModel.Tab]
    let selected: PhraseBoardViewModel.Filter?
    let colorKey: String
    let onSelect: (PhraseBoardViewModel.Filter) -> Void

    @Environment(\.appTheme) private var theme
    @ScaledMetric(relativeTo: .headline) private var tabHeight: CGFloat = 56

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(tabs) { tab in
                        tabButton(tab).id(tab.filter)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .onChange(of: selected) { _, newValue in
                guard let newValue else { return }
                withAnimation { proxy.scrollTo(newValue, anchor: .center) }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Categories")
        // Keep tabs usable at the largest text sizes without pushing phrases off screen.
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
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
