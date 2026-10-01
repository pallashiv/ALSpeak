import SwiftUI

/// A large, soft card for one place on the home screen: an icon in a white circle above
/// the place's name.
struct EnvironmentCard: View {
    let name: String
    let symbolName: String
    let colorKey: String

    @Environment(\.appTheme) private var theme
    @ScaledMetric(relativeTo: .title2) private var scaledMinHeight: CGFloat = 148
    @ScaledMetric(relativeTo: .title2) private var scaledIconSize: CGFloat = 28
    @ScaledMetric(relativeTo: .title2) private var scaledIconCircle: CGFloat = 60

    // The name grows freely with Dynamic Type; the icon and empty space grow only so far,
    // so at the largest sizes the card's height goes to the text, not to decoration.
    private var minHeight: CGFloat { min(scaledMinHeight, 200) }
    private var iconSize: CGFloat { min(scaledIconSize, 40) }
    private var iconCircle: CGFloat { min(scaledIconCircle, 84) }

    var body: some View {
        let colors = Palette.controlColors(colorKey: colorKey, theme: theme)
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: symbolName)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(colors.accent)
                .frame(width: iconCircle, height: iconCircle)
                .background(theme == .highContrast ? Color.clear : Palette.surface, in: Circle())
                .accessibilityHidden(true)
            Spacer(minLength: 0)
            Text(name)
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(colors.foreground)
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
        .controlBackground(colors, cornerRadius: 28)
        .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(name)
        .accessibilityHint("Opens phrases for \(name)")
        .accessibilityAddTraits(.isButton)
    }
}

#Preview {
    VStack {
        HStack {
            EnvironmentCard(name: "Restaurant", symbolName: "fork.knife", colorKey: "orange")
            EnvironmentCard(name: "Emergency", symbolName: "exclamationmark.triangle.fill", colorKey: "red")
        }
        HStack {
            EnvironmentCard(name: "Restaurant", symbolName: "fork.knife", colorKey: "orange")
            EnvironmentCard(name: "Emergency", symbolName: "exclamationmark.triangle.fill", colorKey: "red")
        }
        .environment(\.appTheme, .highContrast)
    }
    .padding()
    .background(Palette.background)
    .fontDesign(.rounded)
}
