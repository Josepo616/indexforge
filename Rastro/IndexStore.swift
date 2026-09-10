//
//  IndexStore.swift
//  Rastro
//
//  Created by JoseAlvarez on 9/9/26.
//


import Foundation

actor IndexStore {

    private var index = InvertedIndex()

    /// Batched insert: one actor hop per batch instead of one per document.
    func insert(_ drafts: [DocumentDraft]) {
        for draft in drafts {
            index.insert(draft)
        }
    }

    func search(terms: [String], limit: Int = 20) -> [SearchResult] {
        index.search(terms: terms, limit: limit)
    }

    var statistics: Statistics {
        Statistics(documentCount: index.documentCount,
                   vocabularySize: index.vocabularySize,
                   averageDocumentLength: index.averageDocumentLength)
    }

    struct Statistics: Sendable {
        let documentCount: Int
        let vocabularySize: Int
        let averageDocumentLength: Double
    }
}