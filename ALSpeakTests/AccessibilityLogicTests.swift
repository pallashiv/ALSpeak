import Foundation
import Testing
@testable import ALSpeak

@MainActor
struct ActivationGateTests {
    let start = Date(timeIntervalSince1970: 1_000)

    @Test func firstActivationIsAllowed() {
        #expect(ActivationGate(interval: 0.4).allow(now: start))
    }

    @Test func rapidSecondActivationIsIgnored() {
        let gate = ActivationGate(interval: 0.4)
        #expect(gate.allow(now: start))
        #expect(!gate.allow(now: start.addingTimeInterval(0.15)))
    }

    @Test func activationAfterIntervalIsAllowed() {
        let gate = ActivationGate(interval: 0.4)
        #expect(gate.allow(now: start))
        #expect(gate.allow(now: start.addingTimeInterval(0.5)))
    }

    @Test func ignoredActivationsDoNotExtendTheWindow() {
        // A tremor burst shouldn't lock the user out: the window runs from the last
        // *accepted* activation.
        let gate = ActivationGate(interval: 0.4)
        #expect(gate.allow(now: start))
        #expect(!gate.allow(now: start.addingTimeInterval(0.3)))
        #expect(gate.allow(now: start.addingTimeInterval(0.45)))
    }
}

struct ThemeTests {
    @Test func systemIncreasedContrastForcesHighContrast() {
        #expect(AppTheme.resolve(.standard, systemIncreasedContrast: true) == .highContrast)
        #expect(AppTheme.resolve(.highContrast, systemIncreasedContrast: false) == .highContrast)
        #expect(AppTheme.resolve(.standard, systemIncreasedContrast: false) == .standard)
    }

    @Test func highContrastControlsAreOutlinedBlack() {
        let colors = Palette.controlColors(tint: Palette.environmentColor("blue"), theme: .highContrast)
        #expect(colors.fill == .black)
        #expect(colors.border == Palette.highContrastAccent)

        let standard = Palette.controlColors(tint: Palette.environmentColor("blue"), theme: .standard)
        #expect(standard.border == nil)
    }
}

struct DisplaySettingsTests {
    @Test func defaults() {
        let settings = UserSettings()
        #expect(settings.showFullScreenPhrase)
        #expect(settings.keepScreenOn)
        #expect(settings.touchMode == .tap)
        #expect(settings.theme == .standard)
    }

    @Test func everyTouchModeHasADescription() {
        for mode in TouchMode.allCases {
            #expect(!SettingsView.touchModeDescription(mode).isEmpty)
        }
    }
}
