//
//  InvertedIndex.swift
//  Rastro
//
//  Created by JoseAlvarez on 9/6/26.
//

import Foundation

typealias DocumentID = Int32

/// One occurrence: in which document, how many times.
struct Posting: Sendable, Equatable {
    let document: DocumentID
    let frequency: Int32
}

/// Document metadata. The URL lives here only once.
struct DocumentRecord: Sendable {
    let url: URL
    let tokenCount: Int
}

/// A tokenized document, ready for insertion. Produced outside the actor.
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

    private(set) var postingsByTerm: [String: [Posting]] = [:]
    private(set) var documents: [DocumentRecord] = []
    private(set) var totalTokens: Int = 0

    var vocabularySize: Int { postingsByTerm.count }

    @discardableResult
    mutating func insert(_ draft: DocumentDraft) -> DocumentID {
        let id = DocumentID(documents.count)
        documents.append(
            DocumentRecord(url: draft.url, tokenCount: draft.tokenCount)
        )
        totalTokens += draft.tokenCount

        for (term, frequency) in draft.frequencies {
            // In-place mutation: avoids the CoW from a naive append.
            postingsByTerm[term, default: []].append(
                Posting(document: id, frequency: frequency)
            )
        }
        return id
    }
}

extension InvertedIndex: PostingsSource {
    func postings(for term: String) -> [Posting] {
        postingsByTerm[term] ?? []
    }
}

extension InvertedIndex {

    func encoded() -> Data {
        var header = ByteWriter()
        header.write(SnapshotFormat.magic)
        header.write(SnapshotFormat.version)
        header.write(UInt32(documents.count))
        header.write(UInt32(postingsByTerm.count))
        header.write(UInt64(totalTokens))

        var body = ByteWriter()
        for record in documents {
            body.write(UInt32(record.tokenCount))
            body.write(record.url.path(percentEncoded: false))
        }

        // Sorted so the file is byte-identical for a given index state.
        let terms = postingsByTerm.keys.sorted()

        var vocabulary = ByteWriter()
        var postingsBlock = ByteWriter()
        var runningOffset: UInt64 = 0

        for term in terms {
            let list = postingsByTerm[term]!
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
