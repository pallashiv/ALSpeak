import SwiftUI
import UIKit

/// App colors.
///
/// The standard look is calm and light: a warm off-white background, soft pastel cards
/// tinted by each place's color, and dark text (well above WCAG AAA 7:1 on every tint).
/// Each color key has:
/// - a **base** color (strong; white text on it passes AAA) for selected tabs and buttons,
/// - an **accent** for icons (lightened in dark mode),
/// - a **soft** tint for card backgrounds.
///
/// The high-contrast theme replaces the pastels with black, outlined in yellow, with
/// white/yellow text — the classic low-vision AAC scheme.
enum Palette {
    private struct RGB {
        let r: CGFloat, g: CGFloat, b: CGFloat

        func mixed(with other: RGB, amount: CGFloat) -> RGB {
            RGB(r: r + (other.r - r) * amount, g: g + (other.g - g) * amount, b: b + (other.b - b) * amount)
        }

        var uiColor: UIColor { UIColor(red: r, green: g, blue: b, alpha: 1) }
    }

    private static let white = RGB(r: 1, g: 1, b: 1)
    private static let darkSurface = RGB(r: 0.11, g: 0.11, b: 0.12)

    private static let bases: [String: RGB] = [
        "blue": RGB(r: 0.05, g: 0.30, b: 0.62),
        "teal": RGB(r: 0.00, g: 0.38, b: 0.40),
        "orange": RGB(r: 0.60, g: 0.26, b: 0.00),
        "green": RGB(r: 0.10, g: 0.38, b: 0.16),
        "purple": RGB(r: 0.35, g: 0.16, b: 0.53),
        "red": RGB(r: 0.66, g: 0.00, b: 0.10),
        "gold": RGB(r: 0.55, g: 0.38, b: 0.00),
        "gray": RGB(r: 0.25, g: 0.25, b: 0.28),
    ]

    private static func base(_ key: String) -> RGB {
        bases[key] ?? bases["gray"]!
    }

    private static func dynamic(light: RGB, dark: RGB) -> Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? dark.uiColor : light.uiColor })
    }

    /// Strong color for a key. White text on it passes WCAG AAA.
    static func environmentColor(_ key: String) -> Color {
        Color(uiColor: base(key).uiColor)
    }

    /// Icon color: the base color in light mode, a lighter version on dark backgrounds.
    static func accent(_ key: String) -> Color {
        dynamic(light: base(key), dark: base(key).mixed(with: white, amount: 0.45))
    }

    /// Pastel card background for a key.
    static func soft(_ key: String) -> Color {
        dynamic(light: base(key).mixed(with: white, amount: 0.87),
                dark: base(key).mixed(with: darkSurface, amount: 0.72))
    }

    /// Keys a user can pick when creating an environment.
    static let environmentColorKeys = ["blue", "teal", "orange", "green", "purple", "red", "gray"]

    /// Color key used for favorites and phrases shown in every place.
    static let favoriteKey = "gold"

    // MARK: Contrast checking

    /// Raw sRGB components behind the palette, for contrast checks in tests.
    enum Swatch {
        case base, accent, soft, background, surface
    }

    static func components(_ swatch: Swatch, key: String = "gray", dark: Bool) -> (r: CGFloat, g: CGFloat, b: CGFloat) {
        let rgb: RGB = switch swatch {
        case .base: base(key)
        case .accent: dark ? base(key).mixed(with: white, amount: 0.45) : base(key)
        case .soft: dark ? base(key).mixed(with: darkSurface, amount: 0.72) : base(key).mixed(with: white, amount: 0.87)
        case .background: dark ? RGB(r: 0.06, g: 0.06, b: 0.07) : RGB(r: 0.969, g: 0.961, b: 0.949)
        case .surface: dark ? darkSurface : white
        }
        return (rgb.r, rgb.g, rgb.b)
    }

    /// WCAG 2 contrast ratio between two sRGB colors (1…21).
    static func contrastRatio(_ a: (r: CGFloat, g: CGFloat, b: CGFloat), _ b: (r: CGFloat, g: CGFloat, b: CGFloat)) -> Double {
        func luminance(_ c: (r: CGFloat, g: CGFloat, b: CGFloat)) -> Double {
            func channel(_ v: CGFloat) -> Double {
                let v = Double(v)
                return v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b)
        }
        let (l1, l2) = (luminance(a), luminance(b))
        return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05)
    }

    static let allColorKeys: [String] = bases.keys.sorted()

    // MARK: Surfaces

    /// Warm off-white page background.
    static let background = dynamic(light: RGB(r: 0.969, g: 0.961, b: 0.949), dark: RGB(r: 0.06, g: 0.06, b: 0.07))
    /// Cards and bars that sit on the background.
    static let surface = dynamic(light: white, dark: darkSurface)
    static let hairline = Color.primary.opacity(0.08)

    /// Full-screen spoken-phrase display.
    static let overlayBackground = background
    static let overlayText = Color.primary

    // MARK: High contrast

    /// Accent for the high-contrast theme (on black: ~15:1).
    static let highContrastAccent = Color(red: 1.0, green: 0.84, blue: 0.04)
    static let highContrastBorderWidth: CGFloat = 3

    /// Colors for a filled control (phrase button, environment card).
    struct ControlColors {
        let fill: Color
        let foreground: Color
        /// For icons and secondary marks.
        let accent: Color
        let border: Color?
    }

    static func controlColors(colorKey: String, theme: AppTheme) -> ControlColors {
        switch theme {
        case .standard:
            ControlColors(fill: soft(colorKey), foreground: .primary, accent: accent(colorKey), border: nil)
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
