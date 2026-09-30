import Testing
@testable import ALSpeak

struct TokenResolverTests {
    @Test func replacesKnownTokens() {
        let result = TokenResolver.resolve(
            "Hi, I'm {name}. Could I have {favoriteDrink}?",
            tokens: ["name": "Sam", "favoriteDrink": "iced tea"]
        )
        #expect(result == "Hi, I'm Sam. Could I have iced tea?")
    }

    @Test func replacesRepeatedTokens() {
        #expect(TokenResolver.resolve("{name} {name}", tokens: ["name": "Sam"]) == "Sam Sam")
    }

    @Test func leavesMissingAndBlankTokensUntouched() {
        let text = "Get {caregiverName} and {name}"
        let result = TokenResolver.resolve(text, tokens: ["name": "  "])
        #expect(result == text)
    }

    @Test func trimsValues() {
        #expect(TokenResolver.resolve("I'm {name}", tokens: ["name": " Sam \n"]) == "I'm Sam")
    }

    @Test func textWithoutTokensIsUnchanged() {
        #expect(TokenResolver.resolve("I'm thirsty", tokens: ["name": "Sam"]) == "I'm thirsty")
    }

    @Test func ignoresBracesThatAreNotTokens() {
        let text = "{ not a token } and {}"
        #expect(TokenResolver.resolve(text, tokens: [:]) == text)
        #expect(TokenResolver.tokenNames(in: text).isEmpty)
    }

    @Test func handlesNonASCIIText() {
        #expect(TokenResolver.resolve("¡Hola {name}! 👋", tokens: ["name": "José"]) == "¡Hola José! 👋")
    }

    @Test func listsTokenNamesInOrderWithoutDuplicates() {
        #expect(TokenResolver.tokenNames(in: "{b} {a} {b}") == ["b", "a"])
    }

    @Test func listsMissingTokens() {
        let missing = TokenResolver.missingTokens(
            in: "{name} wants {favoriteDrink} from {caregiverName}",
            tokens: ["name": "Sam", "favoriteDrink": ""]
        )
        #expect(missing == ["favoriteDrink", "caregiverName"])
    }
}
