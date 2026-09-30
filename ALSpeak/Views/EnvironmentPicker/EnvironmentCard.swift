import SwiftUI

/// A large tappable card for one environment on the home screen.
struct EnvironmentCard: View {
    let name: String
    let symbolName: String
    let colorKey: String

    @ScaledMetric(relativeTo: .title2) private var minHeight: CGFloat = 128
    @ScaledMetric(relativeTo: .title2) private var iconSize: CGFloat = 40

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: symbolName)
                .font(.system(size: iconSize, weight: .semibold))
                .accessibilityHidden(true)
            Spacer(minLength: 0)
            Text(name)
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(.white)
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
        .background(Palette.environmentColor(colorKey), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(name)
        .accessibilityHint("Opens phrases for \(name)")
        .accessibilityAddTraits(.isButton)
    }
}

#Preview {
    HStack {
        EnvironmentCard(name: "Restaurant", symbolName: "fork.knife", colorKey: "orange")
        EnvironmentCard(name: "Emergency", symbolName: "exclamationmark.triangle.fill", colorKey: "red")
    }
    .padding()
}
