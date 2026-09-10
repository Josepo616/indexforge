//
//  InvertedIndex.swift
//  Rastro
//
//  Created by JoseAlvarez on 9/6/26.
//

import Foundation

typealias DocumentID = Int32

/// One occurrence: in which document, how many times
struct Posting: Sendable, Equatable {
    let document: DocumentID
    let frequency: Int32
}

/// Document metadata. The URL lives here only once
struct DocumentRecord: Sendable {
    let url: URL
    let tokenCount: Int
}

/// Document already tokenized, ready for insertion. It is produced outside the actor
struct DocumentDraft: Sendable {
    let url: URL
    let tokenCount: Int
    let frequencies: [String: Int32]

    init(url: URL, text: String, tokenizer: Tokenizer) {
        var frequencies: [String: Int32] = [:]
        var count = 0
        tokenizer.tokenize(text) { token in
            frequencies[token, default: 0] += 1
            count += 1
        }
        self.url = url
        self.tokenCount = count
        self.frequencies = frequencies

    }
}

struct SearchResult: Sendable, Equatable {
    let url: URL
    let score: Double
}

nonisolated struct InvertedIndex: Sendable {

    private(set) var postings: [String: [Posting]] = [:]
    private(set) var documents: [DocumentRecord] = []
    private(set) var totalTokens: Int = 0

    var documentCount: Int { documents.count }
    var vocabularySize: Int { postings.count }

    var averageDocumentLength: Double {
        documents.isEmpty ? 0 : Double(totalTokens) / Double(documents.count)
    }

    @discardableResult
    mutating func insert(_ draft: DocumentDraft) -> DocumentID {
        let id = DocumentID(documents.count)
        documents.append(
            DocumentRecord(url: draft.url, tokenCount: draft.tokenCount)
        )
        totalTokens += draft.tokenCount

        for (term, frequency) in draft.frequencies {
            // In-place mutation: avoids the CoW from a naïve append.
            postings[term, default: []].append(
                Posting(document: id, frequency: frequency)
            )
        }
        return id
    }
}

extension InvertedIndex {

    struct BM25Parameters: Sendable {
        var k1: Double = 1.2
        var b: Double = 0.75
    }

    func search(terms: [String],
                limit: Int = 20,
                parameters: BM25Parameters = BM25Parameters()) -> [SearchResult] {

        guard !documents.isEmpty else { return [] }

        let documentCount = Double(documents.count)
        let averageLength = averageDocumentLength
        var scores: [DocumentID: Double] = [:]

        // Term-at-a-time: one term, its entire list, accumulate
        for term in Set(terms) {
            guard let list = postings[term] else { continue }

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
                return $0.key < $1.key   // Stable tie-breaking by docID
            }
            .prefix(limit)
            .map { SearchResult(url: documents[Int($0.key)].url, score: $0.value) }
    }
}

extension InvertedIndex {

    func encoded() -> Data {
        var header = ByteWriter()
        header.write(SnapshotFormat.magic)
        header.write(SnapshotFormat.version)
        header.write(UInt32(documents.count))
        header.write(UInt32(postings.count))
        header.write(UInt64(totalTokens))

        var body = ByteWriter()
        for record in documents {
            body.write(UInt32(record.tokenCount))
            body.write(record.url.path(percentEncoded: false))
        }

        // Sorted so the file is byte-identical for a given index state.
        let terms = postings.keys.sorted()

        var vocabulary = ByteWriter()
        var postingsBlock = ByteWriter()
        var runningOffset: UInt64 = 0

        for term in terms {
            let list = postings[term]!
            vocabulary.write(term)
            vocabulary.write(runningOffset)
            vocabulary.write(UInt32(list.count))

            for posting in list {
                postingsBlock.write(posting.document)
                postingsBlock.write(posting.frequency)
            }
            runningOffset += UInt64(list.count * 8)
        }

        var output = header.data
        output.append(body.data)
        output.append(vocabulary.data)
        output.append(postingsBlock.data)
        return output
    }
}
