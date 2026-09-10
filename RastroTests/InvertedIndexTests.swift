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

    @Test("empty index does not return results")
    func emptyIndex() {
        #expect(InvertedIndex().search(terms: ["swift"]).isEmpty)
    }

    @Test("missing term returns no results")
    func unknownTerm() {
        let index = index([("a", "swift concurrency")])
        #expect(index.search(terms: ["rust"]).isEmpty)
    }

    @Test("more frequent term ranks higher")
    func frequencyWins() {
        let index = index([
            ("pocas", "swift and other words here"),
            ("muchas", "swift swift swift and a bunch of other words"),
        ])
        #expect(names(index.search(terms: ["swift"])).first == "many")
    }

    @Test("same frequency, shorter document is better")
    func lengthNormalization() {
        let index = index([
            ("largo", "swift " + String(repeating: "thrash ", count: 200)),
            ("corto", "swift breve"),
        ])
        #expect(names(index.search(terms: ["swift"])).first == "short")
    }

    @Test("rare terms are less ambiguous")
    func rareTermOutweighsCommon() {
        let index = index([
            ("comun", "concurrency concurrency concurrency"),
            ("raro", "concurrency actor"),
        ])
        // "actor" appears in 1 of 2 docs, "concurrency" in 2 de 2.
        let results = index.search(terms: ["concurrency", "actor"])
        #expect(names(results).first == "rare")
    }

    @Test("accumulation of corpus statistics")
    func corpusStatistics() {
        let index = index([("a", "one two"), ("b", "three four five")])
        #expect(index.documentCount == 2)
        #expect(index.totalTokens == 5)
        #expect(index.averageDocumentLength == 2.5)
        #expect(index.vocabularySize == 5)
    }

    @Test("respects result limit")
    func respectsLimit() {
        let index = index((0..<10).map { ("doc\($0)", "swift") })
        #expect(index.search(terms: ["swift"], limit: 3).count == 3)
    }
}
