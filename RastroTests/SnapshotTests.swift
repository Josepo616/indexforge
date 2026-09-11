//
//  SnapshotTests.swift
//  Rastro
//
//  Created by JoseAlvarez on 9/10/26.
//

import Foundation
import Testing

@testable import Rastro

@Suite("Snapshot")
struct SnapshotTests {

    private let tokenizer = Tokenizer(stopWords: [])

    private func makeIndex() -> InvertedIndex {
        var index = InvertedIndex()
        for (name, text) in [
            ("a", "swift concurrency actors"),
            ("b", "swift performance tuning"),
            ("c", "actors and mailboxes"),
        ] {
            index.insert(
                DocumentDraft(
                    url: URL(filePath: "/tmp/\(name).txt"),
                    text: text,
                    tokenizer: tokenizer
                )
            )
        }
        return index
    }

    private func temporaryURL() -> URL {
        URL.temporaryDirectory.appending(path: "\(UUID().uuidString).rastro")
    }

    @Test("round-trips corpus statistics")
    func roundTripsStatistics() throws {
        let index = makeIndex()
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let store = SnapshotStore(url: url)
        try store.write(index)
        let loaded = try store.read()

        #expect(loaded.documentCount == index.documentCount)
        #expect(loaded.vocabularySize == index.vocabularySize)
        #expect(loaded.totalTokens == index.totalTokens)
    }

    @Test("round-trips postings lists")
    func roundTripsPostings() throws {
        let index = makeIndex()
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let store = SnapshotStore(url: url)
        try store.write(index)
        let loaded = try store.read()

        #expect(loaded.postings(for: "swift") == index.postingsByTerm["swift"])
        #expect(loaded.postings(for: "actors") == index.postingsByTerm["actors"])
        #expect(loaded.postings(for: "missing").isEmpty)
    }

    @Test("encoding is deterministic")
    func encodingIsDeterministic() {
        #expect(makeIndex().encoded() == makeIndex().encoded())
    }

    @Test("rejects a file with a bad magic number")
    func rejectsBadMagic() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }
        try Data(repeating: 0, count: 64).write(to: url)

        #expect(throws: SnapshotError.self) {
            try SnapshotStore(url: url).read()
        }
    }

    @Test("rejects a truncated file")
    func rejectsTruncatedFile() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }
        try makeIndex().encoded().prefix(20).write(to: url)

        #expect(throws: SnapshotError.self) {
            try SnapshotStore(url: url).read()
        }
    }

    @Test("ranking is identical from memory and from a mapped snapshot")
    func rankingMatchesAcrossBackings() throws {
        let index = makeIndex()
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let store = SnapshotStore(url: url)
        try store.write(index)
        let loaded = try store.read()

        let fromMemory = index.search(terms: ["swift", "actors"])
        let fromDisk = loaded.search(terms: ["swift", "actors"])

        #expect(fromMemory.map(\.url) == fromDisk.map(\.url))
        #expect(fromMemory.count == fromDisk.count)
    }
}
