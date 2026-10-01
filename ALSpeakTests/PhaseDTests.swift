import AVFoundation
import Foundation
import SwiftData
import Testing
@testable import ALSpeak

// MARK: - Type to speak

@MainActor
struct TypeToSpeakViewModelTests {
    let container: ModelContainer
    let viewModel = TypeToSpeakViewModel()
    var context: ModelContext { container.mainContext }
    var editor: PhraseLibraryEditor { PhraseLibraryEditor(context: context) }

    init() throws {
        container = try AppSchema.makeContainer(inMemory: true)
    }

    private func phrases(_ texts: [String]) -> [Phrase] {
        texts.map { text in
            let phrase = Phrase(text: text)
            context.insert(phrase)
            return phrase
        }
    }

    @Test func noSuggestionsForVeryShortInput() {
        viewModel.text = "I"
        #expect(viewModel.suggestions(phrases: phrases(["I'm hungry"]), recents: [], tokens: [:]).isEmpty)
    }

    @Test func prefixMatchesRankBeforeWordAndSubstringMatches() {
        let library = phrases(["Could I have water?", "Water please", "Underwater is fun"])
        viewModel.text = "wat"
        let texts = viewModel.suggestions(phrases: library, recents: [], tokens: [:]).map(\.text)
        #expect(texts == ["Water please", "Could I have water?", "Underwater is fun"])
    }

    @Test func recentsWinTiesAndDuplicatesCollapse() {
        let library = phrases(["Thank you so much"])
        viewModel.text = "thank"
        let suggestions = viewModel.suggestions(
            phrases: library, recents: ["Thank you for coming", "thank you so much"], tokens: [:])
        #expect(suggestions.map(\.text) == ["Thank you for coming", "thank you so much"])
        #expect(suggestions.allSatisfy { $0.phrase == nil })
    }

    @Test func moreUsedLibraryPhrasesRankFirst() {
        let library = phrases(["Help me sit up", "Help me stand"])
        library[1].useCount = 5
        viewModel.text = "help"
        #expect(viewModel.suggestions(phrases: library, recents: [], tokens: [:]).map(\.text)
                == ["Help me stand", "Help me sit up"])
    }

    @Test func suggestionsResolveTokensAndSkipExactInput() {
        let library = phrases(["My name is {name}", "my name"])
        viewModel.text = "my name"
        let texts = viewModel.suggestions(phrases: library, recents: [], tokens: ["name": "Sam"]).map(\.text)
        #expect(texts == ["My name is Sam"])
    }

    @Test func suggestionsAreLimited() {
        let library = phrases((1...10).map { "Option \($0)" })
        viewModel.text = "opt"
        #expect(viewModel.suggestions(phrases: library, recents: [], tokens: [:], limit: 4).count == 4)
    }

    @Test func recordSpokenKeepsNewestFirstWithoutDuplicates() {
        let settings = UserSettings()
        settings.recentTypedTexts = ["b", "Hello there", "c"]
        viewModel.text = " hello there "
        viewModel.recordSpoken(in: settings)
        #expect(settings.recentTypedTexts == ["hello there", "b", "c"])
    }

    @Test func recentsAreCapped() {
        let settings = UserSettings()
        for index in 0..<15 {
            viewModel.text = "Text \(index)"
            viewModel.recordSpoken(in: settings)
        }
        #expect(settings.recentTypedTexts.count == TypeToSpeakViewModel.maxRecents)
        #expect(settings.recentTypedTexts.first == "Text 14")
    }

    @Test func savingCreatesMyPhrasesCategoryOnceAndReusesIt() throws {
        let env = editor.addEnvironment(name: "Cafe", symbolName: "cup.and.saucer.fill", colorKey: "orange")

        viewModel.text = "Oat milk, please"
        let first = try #require(viewModel.save(to: env, using: editor))
        viewModel.text = "No sugar"
        viewModel.save(to: env, using: editor)

        let saved = env.categories.filter { $0.name == TypeToSpeakViewModel.savedCategoryName }
        #expect(saved.count == 1)
        #expect(saved[0].sortedPhrases.map(\.text) == ["Oat milk, please", "No sugar"])
        #expect(first.isUserCreated)
    }

    @Test func savingBlankTextDoesNothing() {
        let env = editor.addEnvironment(name: "Cafe", symbolName: "cup.and.saucer.fill", colorKey: "orange")
        viewModel.text = "  "
        #expect(viewModel.save(to: env, using: editor) == nil)
        #expect(env.categories.count == 1)
    }
}

// MARK: - Quick Respond layout

struct QuickRespondLayoutTests {
    @Test func firstTwoRepliesAreInlineTheRestGoUnderMore() {
        let split = QuickRespondLayout.split(["Yes", "No", "Maybe", "Thank you"])
        #expect(split.inline == ["Yes", "No"])
        #expect(split.more == ["Maybe", "Thank you"])
    }

    @Test func fewRepliesAllFitInline() {
        let split = QuickRespondLayout.split(["Yes"])
        #expect(split.inline == ["Yes"])
        #expect(split.more.isEmpty)
        #expect(QuickRespondLayout.split([]).inline.isEmpty)
    }
}

// MARK: - Settings helpers

struct VoiceOptionTests {
    @Test func choicesFilterAndSort() {
        let voices = [
            VoiceOption(id: "fr", name: "Amélie", language: "fr-FR", quality: .premium),
            VoiceOption(id: "bells", name: "Bells", language: "en-US", quality: .standard, isNovelty: true),
            VoiceOption(id: "gb", name: "Daniel", language: "en-GB", quality: .enhanced),
            VoiceOption(id: "us-std", name: "Fred", language: "en-US", quality: .standard),
            VoiceOption(id: "us-enh", name: "Ava", language: "en-US", quality: .enhanced),
            VoiceOption(id: "us-prem", name: "Zoe", language: "en-US", quality: .premium),
            VoiceOption(id: "pv", name: "My Voice", language: "en-US", quality: .standard, isPersonalVoice: true),
        ]
        let ids = VoiceOption.choices(from: voices, languageCode: "en-US").map(\.id)
        #expect(ids == ["pv", "us-prem", "us-enh", "gb", "us-std"])
    }
}

struct TokenKeyTests {
    @Test(arguments: [
        ("Pet's name", "petSName"),
        ("favorite drink", "favoriteDrink"),
        ("  Doctor  ", "doctor"),
        ("Room 12", "room12"),
    ])
    func makesCamelCaseKeys(label: String, expected: String) {
        #expect(TokenKey.make(from: label) == expected)
    }

    @Test func rejectsLabelsWithoutLettersOrDigits() {
        #expect(TokenKey.make(from: " !? ") == nil)
    }

    @Test func madeKeysWorkAsTokens() throws {
        let key = try #require(TokenKey.make(from: "Pet's name"))
        #expect(TokenResolver.resolve("Meet {\(key)}", tokens: [key: "Rex"]) == "Meet Rex")
    }

    @Test(arguments: [
        ("name", "Your name"),
        ("favoriteDrink", "Favorite drink"),
        ("caregiverName", "Caregiver name"),
        ("doctor", "Doctor"),
    ])
    func displayNames(key: String, expected: String) {
        #expect(TokenKey.displayName(for: key) == expected)
    }
}

struct SettingsViewModelTests {
    @Test func rateLabelIsRelativeToNormalSpeed() {
        #expect(SettingsViewModel.rateLabel(AVSpeechUtteranceDefaultSpeechRate) == "1.0×")
        #expect(SettingsViewModel.rateLabel(0.6) == "1.2×")
    }
}

// MARK: - Emergency & overlay options

@MainActor
struct EmergencyCoordinatorTests {
    let container: ModelContainer
    let synth = MockSynthesizer()
    let haptics = MockHaptics()
    let coordinator: SpeechCoordinator
    var settings: UserSettings { UserSettings.current(in: container.mainContext) }

    init() throws {
        container = try AppSchema.makeContainer(inMemory: true)
        coordinator = SpeechCoordinator(
            speech: SpeechService(synthesizer: synth, audioSession: MockAudioSession()),
            context: container.mainContext,
            haptics: haptics
        )
    }

    @Test func emergencyUsesConfiguredPhraseAndRepeatCount() {
        settings.emergencyPhrase = "Help, {name} needs you"
        settings.emergencyRepeatCount = 3
        settings.tokens = ["name": "Sam"]
        settings.volume = 0.2

        coordinator.speakEmergency()

        #expect(synth.spoken.count == 3)
        #expect(synth.spoken.allSatisfy { $0.speechString == "Help, Sam needs you" && $0.volume == 1 })
        #expect(haptics.emergencyCount == 1)
        #expect(coordinator.displayedText == "Help, Sam needs you")
        #expect(coordinator.isDisplayingEmergency)
    }

    @Test func blankEmergencyPhraseFallsBackToDefault() {
        settings.emergencyPhrase = "   "
        coordinator.speakEmergency()
        #expect(synth.spoken.first?.speechString == "I need help, please come here now.")
    }

    @Test func emergencyOverlayDoesNotAutoDismiss() async throws {
        coordinator.minimumDisplayTime = .milliseconds(10)
        coordinator.lingerAfterSpeech = .milliseconds(10)
        coordinator.speakEmergency()
        synth.spoken.forEach { coordinator.speech.utteranceEnded(ObjectIdentifier($0)) }

        try await Task.sleep(for: .milliseconds(200))
        #expect(coordinator.isDisplayingEmergency)

        coordinator.dismissDisplay()
        #expect(coordinator.displayedText == nil)
        #expect(!coordinator.isDisplayingEmergency)
    }

    @Test func repeatDuringEmergencyRepeatsTheAlert() {
        settings.emergencyRepeatCount = 1
        coordinator.speakEmergency()
        coordinator.repeatDisplayed()
        #expect(synth.spoken.count == 2)
        #expect(haptics.emergencyCount == 2)
    }

    @Test func normalPhraseAfterEmergencyClearsEmergencyStyle() {
        coordinator.speakEmergency()
        coordinator.speak(text: "Thank you")
        #expect(!coordinator.isDisplayingEmergency)
        #expect(coordinator.displayedText == "Thank you")
    }

    @Test func speakingWithoutOverlayStillSpeaksAndBuzzes() {
        coordinator.speak(text: "Hello", showOverlay: false)
        #expect(synth.spoken.map(\.speechString) == ["Hello"])
        #expect(haptics.spokenCount == 1)
        #expect(coordinator.displayedText == nil)
    }

    @Test func newSettingsHaveSafeDefaults() {
        let fresh = UserSettings()
        #expect(fresh.emergencyRequiresHold)
        #expect(fresh.recentTypedTexts.isEmpty)
    }
}
