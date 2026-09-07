//
//  InvertedIndexTests.swift
//  RastroTests
//
//  Created by JoseAlvarez on 9/6/26.
//

import Foundation
import Testing

@testable import Rastro

@Suite("InvertedIndex")
struct InvertedIndexTests {

    private let tokenizer = Tokenizer(stopWords: [])

    private func index(_ documents: [(String, String)]) -> InvertedIndex {
        var index = InvertedIndex()
        for (name, text) in documents {
            index.insert(
                DocumentDraft(
                    url: URL(filePath: "/tmp/\(name)"),
                    text: text,
                    tokenizer: tokenizer
                )
            )
        }
        return index
    }

    private func names(_ results: [SearchResult]) -> [String] {
        results.map { $0.url.lastPathComponent }
    }

    @Test("índice vacío no devuelve resultados")
    func emptyIndex() {
        #expect(InvertedIndex().search(terms: ["swift"]).isEmpty)
    }

    @Test("término ausente no devuelve resultados")
    func unknownTerm() {
        let index = index([("a", "swift concurrency")])
        #expect(index.search(terms: ["rust"]).isEmpty)
    }

    @Test("más frecuencia rankea más alto")
    func frequencyWins() {
        let index = index([
            ("pocas", "swift y algunas otras palabras de relleno aqui"),
            ("muchas", "swift swift swift y algunas otras palabras aqui"),
        ])
        #expect(names(index.search(terms: ["swift"])).first == "muchas")
    }

    @Test("a igual frecuencia, el documento corto rankea más alto")
    func lengthNormalization() {
        let index = index([
            ("largo", "swift " + String(repeating: "relleno ", count: 200)),
            ("corto", "swift breve"),
        ])
        #expect(names(index.search(terms: ["swift"])).first == "corto")
    }

    @Test("el término raro pesa más que el común")
    func rareTermOutweighsCommon() {
        let index = index([
            ("comun", "concurrencia concurrencia concurrencia"),
            ("raro", "concurrencia actor"),
        ])
        // "actor" aparece en 1 de 2 docs, "concurrencia" en 2 de 2.
        let results = index.search(terms: ["concurrencia", "actor"])
        #expect(names(results).first == "raro")
    }

    @Test("acumula estadísticas del corpus")
    func corpusStatistics() {
        let index = index([("a", "uno dos"), ("b", "tres cuatro cinco")])
        #expect(index.documentCount == 2)
        #expect(index.totalTokens == 5)
        #expect(index.averageDocumentLength == 2.5)
        #expect(index.vocabularySize == 5)
    }

    @Test("respeta el límite de resultados")
    func respectsLimit() {
        let index = index((0..<10).map { ("doc\($0)", "swift") })
        #expect(index.search(terms: ["swift"], limit: 3).count == 3)
    }
}
