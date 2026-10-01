import Foundation
import Observation

/// Draft state for adding or editing an environment (name, icon, color).
@MainActor
@Observable
final class EnvironmentEditorViewModel: Identifiable {
    struct SymbolChoice: Identifiable {
        let symbol: String
        /// Spoken by VoiceOver.
        let label: String
        var id: String { symbol }
    }

    /// Icons offered when creating or editing an environment.
    static let symbolChoices: [SymbolChoice] = [
        .init(symbol: "house.fill", label: "House"),
        .init(symbol: "cross.case.fill", label: "Medical"),
        .init(symbol: "stethoscope", label: "Stethoscope"),
        .init(symbol: "pills.fill", label: "Pills"),
        .init(symbol: "bed.double.fill", label: "Bed"),
        .init(symbol: "fork.knife", label: "Restaurant"),
        .init(symbol: "cup.and.saucer.fill", label: "Cafe"),
        .init(symbol: "cart.fill", label: "Shopping"),
        .init(symbol: "figure.roll", label: "Wheelchair"),
        .init(symbol: "car.fill", label: "Car"),
        .init(symbol: "bus.fill", label: "Bus"),
        .init(symbol: "airplane", label: "Airplane"),
        .init(symbol: "person.2.fill", label: "People"),
        .init(symbol: "heart.fill", label: "Heart"),
        .init(symbol: "building.2.fill", label: "Building"),
        .init(symbol: "briefcase.fill", label: "Work"),
        .init(symbol: "graduationcap.fill", label: "School"),
        .init(symbol: "building.columns.fill", label: "Place of worship"),
        .init(symbol: "tree.fill", label: "Outdoors"),
        .init(symbol: "tv.fill", label: "TV"),
        .init(symbol: "phone.fill", label: "Phone"),
        .init(symbol: "exclamationmark.triangle.fill", label: "Warning"),
    ]

    let id = UUID()
    /// nil when creating a new environment.
    let environment: SpeakEnvironment?

    var name: String
    var symbolName: String
    var colorKey: String

    init(environment: SpeakEnvironment? = nil) {
        self.environment = environment
        self.name = environment?.name ?? ""
        self.symbolName = environment?.symbolName ?? Self.symbolChoices[0].symbol
        self.colorKey = environment?.colorKey ?? Palette.environmentColorKeys[0]
    }

    var isNew: Bool { environment == nil }
    var trimmedName: String { name.trimmed }
    var canSave: Bool { !trimmedName.isEmpty }

    @discardableResult
    func save(using editor: PhraseLibraryEditor) -> SpeakEnvironment? {
        guard canSave else { return nil }
        if let environment {
            editor.update(environment, name: trimmedName, symbolName: symbolName, colorKey: colorKey)
            return environment
        }
        return editor.addEnvironment(name: trimmedName, symbolName: symbolName, colorKey: colorKey)
    }
}
