//
//  TokenizerTest.swift
//  RastroTests
//
//  Created by JoseAlvarez on 8/31/26.
//

import Testing

@testable import Rastro

@Suite("Tokenizer")
struct TokenizerTests {

    let tokenizer = Tokenizer(stopWords: [])

    @Test("Split by non Alphanumeric characters")
    func splitOnPunctuation() {
        #expect(
            tokenizer.tokens(in: "hello,world;again-again") == [
                "hello", "world", "again", "again",
            ]
        )
    }
    
    @Test("normalize accented characters and case")
        func foldsDiacriticsAndCase() {
            #expect(tokenizer.tokens(in: "Café CAFÉ cafe") == ["cafe", "cafe", "cafe"])
        }
    
    @Test("preserving numbers")
        func keepsDigits() {
            #expect(tokenizer.tokens(in: "swift 6.2 macOS26")
                    == ["swift", "macos26"])
        }
    
    @Test("discarding short tokens")
        func dropsShortTokens() {
            #expect(tokenizer.tokens(in: "a de b casa") == ["de", "casa"])
        }
    
    @Test("discard stop words")
        func dropsStopWords() {
            let t = Tokenizer(stopWords: ["de", "la"])
            #expect(t.tokens(in: "la casa de piedra") == ["casa", "piedra"])
        }
    
    @Test("empty text does not emit something")
        func handlesEmpty() {
            #expect(tokenizer.tokens(in: "   ...   ").isEmpty)
        }

    /*@Test func <#test function name#>() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }*/

}
