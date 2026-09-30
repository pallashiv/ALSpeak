import SwiftUI

/// Horizontal row of large category chips ("All", "Ordering", "Needs"…) that filter the board.
struct CategoryChipBar: View {
    let categories: [PhraseCategory]
    @Binding var filter: PhraseBoardViewModel.Filter
    let tint: Color

    @ScaledMetric(relativeTo: .headline) private var chipHeight: CGFloat = 60

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
                .foregroundStyle(isSelected ? .white : tint)
                .background {
                    Capsule().fill(isSelected ? tint : Color(.systemBackground))
                    Capsule().strokeBorder(tint, lineWidth: 2)
                }
        }
        .buttonStyle(PressFeedbackButtonStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
