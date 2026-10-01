import Foundation
import SwiftData
import Testing
@testable import ALSpeak

@MainActor
struct PhraseEditorViewModelTests {
    let container: ModelContainer
    let environment: SpeakEnvironment
    var context: ModelContext { container.mainContext }
    var editor: PhraseLibraryEditor { PhraseLibraryEditor(context: context) }

    init() throws {
        container = try AppSchema.makeContainer(inMemory: true)
        let editor = PhraseLibraryEditor(context: container.mainContext)
        environment = editor.addEnvironment(name: "Cafe", symbolName: "cup.and.saucer.fill", colorKey: "orange")
        editor.addCategory(named: "Ordering", to: environment)
    }

    @Test func newPhraseRequiresText() {
        let vm = PhraseEditorViewModel(newIn: environment.sortedCategories[0])
        #expect(vm.isNew)
        #expect(!vm.canSave)
        vm.text = "   "
        #expect(!vm.canSave)
        #expect(vm.save(using: editor) == nil)
        vm.text = "A latte, please"
        #expect(vm.canSave)
    }

    @Test func savingNewPhraseUsesSelectedCategoryAndFlags() throws {
        let vm = PhraseEditorViewModel(newIn: environment.sortedCategories[0], text: " A latte, please ")
        #expect(vm.categories.map(\.name) == ["General", "Ordering"])
        vm.categoryID = environment.sortedCategories[1].id
        vm.isFavorite = true

        let phrase = try #require(vm.save(using: editor))
        #expect(phrase.text == "A latte, please")
        #expect(phrase.category?.name == "Ordering")
        #expect(phrase.isFavorite)
        #expect(phrase.isUserCreated)
    }

    @Test func editingLoadsAndSavesExistingPhrase() {
        let phrase = editor.addPhrase(text: "Hello", to: environment.sortedCategories[0], showEverywhere: true)
        let vm = PhraseEditorViewModel(phrase: phrase)
        #expect(!vm.isNew)
        #expect(vm.text == "Hello")
        #expect(vm.showEverywhere)

        vm.text = "Hello there"
        vm.showEverywhere = false
        vm.save(using: editor)

        #expect(phrase.text == "Hello there")
        #expect(!phrase.showEverywhere)
    }

    @Test func deleteRemovesPhrase() throws {
        let phrase = editor.addPhrase(text: "Bye", to: environment.sortedCategories[0])
        PhraseEditorViewModel(phrase: phrase).delete(using: editor)
        #expect(try context.fetchCount(FetchDescriptor<Phrase>()) == 0)
    }

    @Test func insertTokenAddsSpacingOnlyWhenNeeded() {
        let vm = PhraseEditorViewModel(newIn: environment.sortedCategories[0])
        vm.insertToken("name")
        #expect(vm.text == "{name}")

        vm.text = "My name is"
        vm.insertToken("name")
        #expect(vm.text == "My name is {name}")

        vm.text = "Hi "
        vm.insertToken("name")
        #expect(vm.text == "Hi {name}")
    }
}

@MainActor
struct EnvironmentEditorViewModelTests {
    let container: ModelContainer
    var editor: PhraseLibraryEditor { PhraseLibraryEditor(context: container.mainContext) }

    init() throws {
        container = try AppSchema.makeContainer(inMemory: true)
    }

    @Test func newEnvironmentRequiresName() {
        let vm = EnvironmentEditorViewModel()
        #expect(vm.isNew)
        #expect(!vm.canSave)
        #expect(vm.save(using: editor) == nil)
    }

    @Test func savingNewEnvironment() throws {
        let vm = EnvironmentEditorViewModel()
        vm.name = "Church"
        vm.symbolName = "building.columns.fill"
        vm.colorKey = "purple"

        let env = try #require(vm.save(using: editor))
        #expect(env.name == "Church")
        #expect(env.symbolName == "building.columns.fill")
        #expect(env.colorKey == "purple")
    }

    @Test func editingExistingEnvironment() {
        let env = editor.addEnvironment(name: "Car", symbolName: "car.fill", colorKey: "blue")
        let vm = EnvironmentEditorViewModel(environment: env)
        #expect(vm.name == "Car")
        vm.name = "Van"
        vm.save(using: editor)
        #expect(env.name == "Van")
    }

    @Test func symbolChoicesAreUnique() {
        let symbols = EnvironmentEditorViewModel.symbolChoices.map(\.symbol)
        #expect(Set(symbols).count == symbols.count)
    }
}
