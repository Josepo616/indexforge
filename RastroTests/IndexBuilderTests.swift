//
//  IndexBuilderTests.swift
//  Rastro
//
//  Created by JoseAlvarez on 9/9/26.
//


import Testing
import Foundation
@testable import Rastro

@Suite("IndexBuilder")
struct IndexBuilderTests {

    private func makeCorpus(_ files: [(String, String)]) throws -> URL {
        let root = URL.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        for (name, contents) in files {
            try contents.write(to: root.appending(path: name), atomically: true, encoding: .utf8)
        }
        return root
    }

    @Test("indexes a directory tree")
    func indexesDirectory() async throws {
        let root = try makeCorpus([
            ("a.txt", "swift concurrency actors"),
            ("b.txt", "swift performance"),
            ("c.txt", "unrelated content here")
        ])
        defer { try? FileManager.default.removeItem(at: root) }

        let store = IndexStore()
        await IndexBuilder().build(at: root, into: store)

        let statistics = await store.statistics
        #expect(statistics.documentCount == 3)

        let results = await store.search(terms: ["swift"])
        #expect(results.count == 2)
    }

    @Test("skips files with unsupported extensions")
    func skipsUnsupportedExtensions() async throws {
        let root = try makeCorpus([
            ("keep.txt", "swift"),
            ("skip.bin", "swift")
        ])
        defer { try? FileManager.default.removeItem(at: root) }

        let store = IndexStore()
        await IndexBuilder().build(at: root, into: store)

        let statistics = await store.statistics
        #expect(statistics.documentCount == 1)
    }

    @Test("reports progress up to the total")
    func reportsProgress() async throws {
        let root = try makeCorpus((0..<10).map { ("f\($0).txt", "swift") })
        defer { try? FileManager.default.removeItem(at: root) }

        let counter = Counter()
        let store = IndexStore()
        await IndexBuilder().build(at: root, into: store) { completed, total in
            counter.record(completed: completed, total: total)
        }

        #expect(counter.lastTotal == 10)
        #expect(counter.calls == 10)
    }

    @Test("results are equivalent regardless of concurrency level")
    func concurrencyDoesNotChangeResults() async throws {
        let root = try makeCorpus((0..<40).map {
            ("f\($0).txt", "swift concurrency document number \($0)")
        })
        defer { try? FileManager.default.removeItem(at: root) }

        let serialStore = IndexStore()
        await IndexBuilder(concurrency: 1).build(at: root, into: serialStore)

        let parallelStore = IndexStore()
        await IndexBuilder(concurrency: 8).build(at: root, into: parallelStore)

        let serial = await serialStore.search(terms: ["swift"], limit: 100)
        let parallel = await parallelStore.search(terms: ["swift"], limit: 100)

        #expect(Set(serial.map(\.url)) == Set(parallel.map(\.url)))
    }
}

/// Small helper so the progress closure has somewhere safe to write.
private final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private(set) var calls = 0
    private(set) var lastTotal = 0

    func record(completed: Int, total: Int) {
        lock.lock(); defer { lock.unlock() }
        calls += 1
        lastTotal = total
    }
}