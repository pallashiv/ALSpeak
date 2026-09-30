import SwiftUI

/// App colors. Environment colors are dark enough that white text on them meets
/// WCAG AAA (7:1) contrast, so phrase buttons stay readable in bright light.
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

    /// Keys a user can pick when creating an environment (phase c).
    static let environmentColorKeys = ["blue", "teal", "orange", "green", "purple", "red", "gray"]

    /// Pinned/favorite phrases use a neutral dark tone so they stand apart from the category color.
    static let pinned = Color(red: 0.16, green: 0.16, blue: 0.20)

    /// Full-screen spoken-phrase overlay.
    static let overlayBackground = Color.black
    static let overlayText = Color.white
}
