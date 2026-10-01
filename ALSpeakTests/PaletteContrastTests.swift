import CoreGraphics
import Testing
@testable import ALSpeak

/// Checks every color pairing the app draws against WCAG 2 contrast thresholds, in both
/// light and dark mode. These numbers are exact, unlike the UI accessibility audit's
/// pixel-sampled contrast check, which misreads composite controls (e.g. a tinted card with
/// a white icon circle).
///
/// Thresholds: 7:1 (AAA) for phrase text, 4.5:1 (AA) for other text, 3:1 for icons.
struct PaletteContrastTests {
    static let black: (r: CGFloat, g: CGFloat, b: CGFloat) = (0, 0, 0)
    static let white: (r: CGFloat, g: CGFloat, b: CGFloat) = (1, 1, 1)
    static let modes = [false, true] // light, dark

    /// Primary text color in each mode.
    static func text(dark: Bool) -> (r: CGFloat, g: CGFloat, b: CGFloat) { dark ? white : black }

    @Test func ratioMatchesKnownValues() {
        #expect(abs(Palette.contrastRatio(Self.black, Self.white) - 21) < 0.01)
        #expect(abs(Palette.contrastRatio(Self.white, Self.white) - 1) < 0.01)
    }

    @Test(arguments: Palette.allColorKeys)
    func phraseAndCardTextMeetsAAA(key: String) {
        for dark in Self.modes {
            let ratio = Palette.contrastRatio(Self.text(dark: dark), Palette.components(.soft, key: key, dark: dark))
            #expect(ratio >= 7, "\(key) \(dark ? "dark" : "light"): \(ratio)")
        }
    }

    @Test(arguments: Palette.allColorKeys)
    func whiteTextOnSelectedTabMeetsAA(key: String) {
        let ratio = Palette.contrastRatio(Self.white, Palette.components(.base, key: key, dark: false))
        #expect(ratio >= 4.5, "\(key): \(ratio)")
    }

    @Test(arguments: Palette.allColorKeys)
    func setupHintTextOnCardMeetsAA(key: String) {
        // The small "Add your name in Settings" hint uses the accent color on the card tint.
        for dark in Self.modes {
            let ratio = Palette.contrastRatio(Palette.components(.accent, key: key, dark: dark),
                                              Palette.components(.soft, key: key, dark: dark))
            #expect(ratio >= 4.5, "\(key) \(dark ? "dark" : "light"): \(ratio)")
        }
    }

    @Test(arguments: Palette.allColorKeys)
    func iconsMeetNonTextContrast(key: String) {
        // Place icons sit in a surface-colored circle; ✓ / ✕ / ★ sit on the soft tint.
        for dark in Self.modes {
            let accent = Palette.components(.accent, key: key, dark: dark)
            let onSurface = Palette.contrastRatio(accent, Palette.components(.surface, dark: dark))
            let onSoft = Palette.contrastRatio(accent, Palette.components(.soft, key: key, dark: dark))
            #expect(onSurface >= 3, "\(key) on surface \(dark ? "dark" : "light"): \(onSurface)")
            #expect(onSoft >= 3, "\(key) on tint \(dark ? "dark" : "light"): \(onSoft)")
        }
    }

    @Test func pageTextMeetsAAA() {
        for dark in Self.modes {
            let onBackground = Palette.contrastRatio(Self.text(dark: dark), Palette.components(.background, dark: dark))
            let onSurface = Palette.contrastRatio(Self.text(dark: dark), Palette.components(.surface, dark: dark))
            #expect(onBackground >= 7)
            #expect(onSurface >= 7)
        }
    }
}
