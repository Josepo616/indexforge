//
//  IndexBuilder.swift
//  Rastro
//
//  Created by JoseAlvarez on 9/9/26.
//


import Foundation

nonisolated struct IndexBuilder: Sendable {

    let tokenizer: Tokenizer
    let crawler: FileCrawler
    let concurrency: Int
    let batchSize: Int

    init(tokenizer: Tokenizer = Tokenizer(),
         crawler: FileCrawler = FileCrawler(),
         concurrency: Int = ProcessInfo.processInfo.activeProcessorCount,
         batchSize: Int = 64) {
        self.tokenizer = tokenizer
        self.crawler = crawler
        self.concurrency = max(1, concurrency)
        self.batchSize = max(1, batchSize)
    }

    func build(at root: URL,
               into store: IndexStore,
               onProgress: @Sendable (Int, Int) -> Void = { _, _ in }) async {

        let urls = crawler.collectFiles(at: root)
        guard !urls.isEmpty else { return }

        let total = urls.count
        var completed = 0
        var batch: [DocumentDraft] = []
        batch.reserveCapacity(batchSize)

        await withTaskGroup(of: DocumentDraft?.self) { group in
            var iterator = urls.makeIterator()

            // Prime the sliding window.
            for _ in 0..<concurrency {
                guard let url = iterator.next() else { break }
                group.addTask { await Self.makeDraft(for: url, tokenizer: tokenizer) }
            }

            for await draft in group {
                completed += 1
                onProgress(completed, total)

                if let draft {
                    batch.append(draft)
                    if batch.count >= batchSize {
                        await store.insert(batch)
                        batch.removeAll(keepingCapacity: true)
                    }
                }

                // Refill: one in, one out.
                if let url = iterator.next() {
                    group.addTask { await Self.makeDraft(for: url, tokenizer: tokenizer) }
                }
            }
        }

        if !batch.isEmpty {
            await store.insert(batch)
        }
    }

    /// `@concurrent` opts this out of the module's MainActor default.
    /// Without it, every worker would queue on the main thread.
    @concurrent
    private static func makeDraft(for url: URL,
                                  tokenizer: Tokenizer) async -> DocumentDraft? {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }
        return DocumentDraft(url: url, text: text, tokenizer: tokenizer)
    }
}