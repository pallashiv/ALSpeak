# ALSpeak

A native iOS speech aid for people living with ALS who have limited speech and limited
motor ability. Pick where you are (Home, Doctor, Restaurant…) and tap large, pre-written
phrases to speak them aloud. Speed, reliability and low physical effort come first.

Fully offline: no accounts, no backend. Speech uses Apple's on-device voices, including
the user's own **Personal Voice** if they've recorded one.

## Running

Requirements: Xcode 16 or later (built with Xcode 26.2), iOS 17+.

```sh
open ALSpeak.xcodeproj        # then ⌘R to run, ⌘U to test
```

Command line:

```sh
xcodebuild test -project ALSpeak.xcodeproj -scheme ALSpeak \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

The first launch loads the phrase library from `ALSpeak/Resources/SeedPhrases.json`.

## Features

- **Places → phrases in two taps.** Big cards for each place; each place's phrases are
  shown one category at a time with large tabs. Favorites appear on the home screen and
  in a Favorites tab.
- **Quick replies on every screen.** Yes / No are always on the bottom bar; **More** opens
  the rest plus *Type a message*. No sideways scrolling anywhere.
- **SOS button** on every screen: hold for one second (tremor-safe) to speak the emergency
  message at full volume, repeated, with a red full-screen alert.
- **Full-screen display** of every spoken phrase so the listener can read it too.
- **Type to speak** with suggestions, recent texts, and one-tap *Save* to the current place.
- **Personalization:** add / edit / reorder / hide places, categories and phrases; personal
  details such as `{name}` filled in when spoken; voice, speed, pitch and volume.
- **Accessibility:** tap, *press-and-hold* or *dwell* selection; repeat-tap filtering for
  tremor; high-contrast theme (also follows iOS Increase Contrast); Dynamic Type; VoiceOver,
  Switch Control and Voice Control labels; Large Content Viewer on the bottom bar; plays
  even when the phone is on silent; optional keep-screen-on.

## Architecture

MVVM with SwiftUI and SwiftData.

```
ALSpeak/
├── App/             ALSpeakApp (container, seeding, launch args), RootView (layout, theme, overlay)
├── Models/          SpeakEnvironment → PhraseCategory → Phrase, UserSettings, AppSchema
├── Services/        SpeechService (AVSpeechSynthesizer wrapper), AudioSessionManager,
│                    Haptics, SeedDataLoader, TokenResolver, PhraseLibraryEditor
├── ViewModels/      SpeechCoordinator (the one way to speak), board / picker / editor /
│                    type-to-speak / settings view models
├── Views/           EnvironmentPicker, PhraseBoard, QuickRespond, TypeToSpeak, Editing,
│                    Settings, Components (PhraseButton, EmergencyButton, Selectable,
│                    FlowLayout, SpokenPhraseOverlay), Theme (Palette)
├── Resources/       SeedPhrases.json
└── Preview/         In-memory SwiftData container for SwiftUI previews
ALSpeakTests/        Unit tests (Swift Testing): models, seeding, speech, view models, contrast
ALSpeakUITests/      End-to-end UI tests + Apple accessibility audits
```

Key ideas:

- **`SpeechCoordinator`** is the single entry point for speaking: it fills in tokens,
  applies voice settings, speaks, buzzes, shows the text full-screen and records usage, so
  every button behaves the same way.
- **`SpeechService`** wraps `AVSpeechSynthesizer` behind a protocol (interrupt, queue, stop,
  emergency) and tracks each utterance, so tests run against a mock synthesizer.
- **`PhraseLibraryEditor`** does every add / edit / reorder / delete, keeping sort orders and
  saves consistent across screens.
- **`Palette`** defines all colors; `PaletteContrastTests` checks every pairing against WCAG
  in light and dark mode.

## Editing the default phrases

Edit `ALSpeak/Resources/SeedPhrases.json`. A phrase is either a string or an object:

```json
{ "text": "My name is {name}", "showEverywhere": true, "isFavorite": false }
```

Tokens in `{braces}` must be declared in the top-level `tokens` object (a unit test checks
this). The library loads only on first launch; delete the app to reload it.

## Debug launch arguments

| Argument | Effect |
| --- | --- |
| `-UITesting` | Fresh in-memory store seeded with the default library (used by UI tests). |
| `-OpenPlace "Restaurant"` | Opens that place's board on launch (debug builds only). |
| `-ShowSpoken "Hello"` | Speaks and shows text full-screen on launch (debug builds only). |
| `-ExpandMore` | Opens the quick-reply *More* panel on launch (debug builds only). |

## Ideas for later

Context-aware suggestions (usage data is already recorded on each phrase: `useCount`,
`lastUsedAt`), location-based place switching, eye-tracking input, and phrase learning.
