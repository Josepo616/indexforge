//
//  IndexStore.swift
//  Rastro
//
//  Created by JoseAlvarez on 9/9/26.
//


import Foundation

actor IndexStore {

    /// Two backings, deliberately not an enum: mutating an enum payload would
    /// hold a second reference to the postings dictionary and trigger a full
    /// copy-on-write on every batch.
    private var index = InvertedIndex()
    private var persisted: PersistedIndex?

    private var active: any PostingsSource { persisted ?? index }

    func insert(_ drafts: [DocumentDraft]) {
        persisted = nil          // building invalidates the mapped snapshot
        for draft in drafts {
            index.insert(draft)
        }
    }

    func reset() {
        index = InvertedIndex()
        persisted = nil
    }

    func search(terms: [String], limit: Int = 20) -> [SearchResult] {
        active.search(terms: terms, limit: limit)
    }

    func save(to snapshot: SnapshotStore) throws {
        guard persisted == nil else { return }   // already on disk, unchanged
        try snapshot.write(index)
    }

    func load(from snapshot: SnapshotStore) throws {
        persisted = try snapshot.read()
        index = InvertedIndex()                  // release the RAM copy
    }

    var statistics: Statistics {
        let source = active
        return Statistics(documentCount: source.documentCount,
                          vocabularySize: vocabularySize,
                          averageDocumentLength: source.averageDocumentLength)
    }

    private var vocabularySize: Int {
        persisted?.vocabulary.count ?? index.vocabularySize
    }

    struct Statistics: Sendable {
        let documentCount: Int
        let vocabularySize: Int
        let averageDocumentLength: Double
    }
}
