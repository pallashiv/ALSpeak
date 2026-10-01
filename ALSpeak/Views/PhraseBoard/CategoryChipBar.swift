import SwiftUI

/// Horizontal row of large category chips ("All", "Ordering", "Needs"…) that filter the board.
struct CategoryChipBar: View {
    let categories: [PhraseCategory]
    @Binding var filter: PhraseBoardViewModel.Filter
    let tint: Color

    @Environment(\.appTheme) private var theme
    @ScaledMetric(relativeTo: .headline) private var chipHeight: CGFloat = 60

    /// In high contrast: yellow when selected, outlined black otherwise.
    private var accent: Color { theme == .highContrast ? Palette.highContrastAccent : tint }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                chip("All", value: .all)
                ForEach(categories) { category in
                    chip(category.name, value: .category(category.id))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Categories")
        // Keep chips usable at the largest text sizes without pushing phrases off screen.
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }

    private func chip(_ title: String, value: PhraseBoardViewModel.Filter) -> some View {
        let isSelected = filter == value
        return Button {
            filter = value
        } label: {
            Text(title)
                .font(.headline)
                .padding(.horizontal, 20)
                .frame(minWidth: 72, minHeight: chipHeight)
                .foregroundStyle(isSelected ? (theme == .highContrast ? Color.black : .white) : accent)
                .background {
                    Capsule().fill(isSelected ? accent : Color(.systemBackground))
                    Capsule().strokeBorder(accent, lineWidth: theme == .highContrast ? Palette.highContrastBorderWidth : 2)
                }
        }
        .buttonStyle(PressFeedbackButtonStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
