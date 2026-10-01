import SwiftUI

/// App colors. Environment colors are dark enough that white text on them meets
/// WCAG AAA (7:1) contrast, so phrase buttons stay readable in bright light.
///
/// The high-contrast theme replaces colored fills with black, outlined in yellow or white,
/// with white/yellow text — the classic low-vision AAC scheme.
enum Palette {
    static func environmentColor(_ key: String) -> Color {
        switch key {
        case "blue": Color(red: 0.05, green: 0.30, blue: 0.62)
        case "teal": Color(red: 0.00, green: 0.38, blue: 0.40)
        case "orange": Color(red: 0.60, green: 0.26, blue: 0.00)
        case "green": Color(red: 0.10, green: 0.38, blue: 0.16)
        case "purple": Color(red: 0.35, green: 0.16, blue: 0.53)
        case "red": Color(red: 0.66, green: 0.00, blue: 0.10)
        default: Color(red: 0.25, green: 0.25, blue: 0.28)
        }
    }

    /// Keys a user can pick when creating an environment.
    static let environmentColorKeys = ["blue", "teal", "orange", "green", "purple", "red", "gray"]

    /// Pinned/favorite phrases use a neutral dark tone so they stand apart from the category color.
    static let pinned = Color(red: 0.16, green: 0.16, blue: 0.20)

    /// Full-screen spoken-phrase overlay.
    static let overlayBackground = Color.black
    static let overlayText = Color.white

    // MARK: High contrast

    /// Accent for the high-contrast theme (on black: ~15:1).
    static let highContrastAccent = Color(red: 1.0, green: 0.84, blue: 0.04)
    static let highContrastBorderWidth: CGFloat = 3

    /// Colors for a filled, speaking control (phrase button, environment card).
    struct ControlColors {
        let fill: Color
        let foreground: Color
        /// Accent for icons / secondary marks.
        let accent: Color
        let border: Color?
    }

    static func controlColors(tint: Color, theme: AppTheme) -> ControlColors {
        switch theme {
        case .standard:
            ControlColors(fill: tint, foreground: .white, accent: .white, border: nil)
        case .highContrast:
            ControlColors(fill: .black, foreground: .white, accent: highContrastAccent, border: highContrastAccent)
        }
    }
}

extension View {
    /// Fills with `colors.fill` and, in high contrast, draws the thick outline.
    func controlBackground(_ colors: Palette.ControlColors, cornerRadius: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return background(colors.fill, in: shape)
            .overlay {
                if let border = colors.border {
                    shape.strokeBorder(border, lineWidth: Palette.highContrastBorderWidth)
                }
            }
    }
}
