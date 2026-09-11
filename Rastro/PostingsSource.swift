//
//  PostingsSource.swift
//  Rastro
//
//  Created by JoseAlvarez on 9/10/26.
//


import Foundation

/// Ranking works the same whether postings live in RAM or in a mapped file.
nonisolated protocol PostingsSource: Sendable {
    var documents: [DocumentRecord] { get }
    var totalTokens: Int { get }
    func postings(for term: String) -> [Posting]
}

extension PostingsSource {

    var documentCount: Int { documents.count }

    var averageDocumentLength: Double {
        documents.isEmpty ? 0 : Double(totalTokens) / Double(documents.count)
    }

    func search(terms: [String],
                limit: Int = 20,
                parameters: BM25Parameters = BM25Parameters()) -> [SearchResult] {

        guard !documents.isEmpty else { return [] }

        let documentCount = Double(documents.count)
        let averageLength = averageDocumentLength
        var scores: [DocumentID: Double] = [:]

        for term in Set(terms) {
            let list = postings(for: term)
            guard !list.isEmpty else { continue }

            let documentFrequency = Double(list.count)
            let idf = log(1 + (documentCount - documentFrequency + 0.5)
                            / (documentFrequency + 0.5))

            for posting in list {
                let frequency = Double(posting.frequency)
                let length = Double(documents[Int(posting.document)].tokenCount)
                let normalization = parameters.k1
                    * (1 - parameters.b + parameters.b * length / averageLength)

                scores[posting.document, default: 0] +=
                    idf * (frequency * (parameters.k1 + 1)) / (frequency + normalization)
            }
        }

        return scores
            .sorted {
                if $0.value != $1.value { return $0.value > $1.value }
                return $0.key < $1.key
            }
            .prefix(limit)
            .map { SearchResult(url: documents[Int($0.key)].url, score: $0.value) }
    }
}

nonisolated struct BM25Parameters: Sendable {
    var k1: Double = 1.2
    var b: Double = 0.75
}