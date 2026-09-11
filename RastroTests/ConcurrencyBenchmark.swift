//
//  ConcurrencyBenchmark.swift
//  Rastro
//
//  Created by JoseAlvarez on 9/10/26.
//

import Foundation
import Testing

@testable import Rastro

/// Not a correctness test. Run manually against a real corpus to produce the
/// numbers behind the concurrency section.
///
/// Set RASTRO_CORPUS to a folder path to enable it.
@Suite(
    "Benchmarks",
    .serialized,
    .enabled(if: ProcessInfo.processInfo.environment["RASTRO_CORPUS"] != nil)
)
struct ConcurrencyBenchmark {

    private var corpus: URL {
        URL(filePath: ProcessInfo.processInfo.environment["RASTRO_CORPUS"]!)
    }

    @Test("indexing throughput across concurrency levels")
    func throughputCurve() async throws {
        for level in [1, 12] {
            let store = IndexStore()
            let start = ContinuousClock.now
            await IndexBuilder(concurrency: level).build(at: corpus, into: store)
            let elapsed = Double((ContinuousClock.now - start)
                .components.attoseconds) / 1e18

            let produced = await store.statistics
            print(String(format: "workers %2d → %6d docs in %.2f s",
                         level, produced.documentCount, elapsed))
        }
    }

    @Test("snapshot size and load time")
    func snapshotCost() async throws {
        let store = IndexStore()
        await IndexBuilder().build(at: corpus, into: store)

        let indexed = await store.statistics
        try #require(
            indexed.documentCount > 0,
            "corpus is empty — check sandbox access"
        )

        let url = URL.temporaryDirectory.appending(path: "benchmark.rastro")
        defer { try? FileManager.default.removeItem(at: url) }
        let snapshot = SnapshotStore(url: url)

        let writeStart = ContinuousClock.now
        try await store.save(to: snapshot)
        let writeElapsed =
            Double(
                (ContinuousClock.now - writeStart)
                    .components.attoseconds
            ) / 1e18

        let size =
            (try? FileManager.default
                .attributesOfItem(atPath: url.path(percentEncoded: false))[
                    .size
                ] as? Int) ?? 0

        let loadStart = ContinuousClock.now
        let fresh = IndexStore()
        try await fresh.load(from: snapshot)
        let loadElapsed =
            Double(
                (ContinuousClock.now - loadStart)
                    .components.attoseconds
            ) / 1e18

        let statistics = await fresh.statistics

        print("\ndocuments:   \(statistics.documentCount)")
        print("terms:       \(statistics.vocabularySize)")
        print(String(format: "snapshot:    %.1f MB", Double(size) / 1_048_576))
        print(String(format: "write:       %.3f s", writeElapsed))
        print(String(format: "mmap load:   %.3f s", loadElapsed))
        print("")
    }

    @Test("search latency")
    func searchLatency() async throws {
        let store = IndexStore()
        await IndexBuilder().build(at: corpus, into: store)

        let indexed = await store.statistics
        try #require(
            indexed.documentCount > 0,
            "corpus is empty — check sandbox access"
        )

        let queries = ["swift", "actor concurrency", "pokedex", "index"]

        print("")
        for query in queries {
            let terms = Tokenizer().tokens(in: query)

            // Warm up, then take the best of 20 to filter scheduling noise.
            _ = await store.search(terms: terms)

            var best = Double.infinity
            for _ in 0..<20 {
                let start = ContinuousClock.now
                _ = await store.search(terms: terms)
                let elapsed =
                    Double(
                        (ContinuousClock.now - start)
                            .components.attoseconds
                    ) / 1e18
                best = min(best, elapsed)
            }
            print(
                String(format: "%-22@ %8.3f ms", query as NSString, best * 1000)
            )
        }
        print("")
    }
}
