//
//  SnapshotStore.swift
//  Rastro
//
//  Created by JoseAlvarez on 9/10/26.
//


import Foundation

nonisolated struct SnapshotStore: Sendable {

    let url: URL

    func write(_ index: InvertedIndex) throws {
        try index.encoded().write(to: url, options: .atomic)
    }

    func read() throws -> PersistedIndex {
        let descriptor = open(url.path(percentEncoded: false), O_RDONLY)
        guard descriptor >= 0 else { throw SnapshotError.mappingFailed(errno) }
        defer { close(descriptor) }

        let data = try Data(contentsOf: url, options: .alwaysMapped)
        var reader = ByteReader(data)

        guard try reader.read(UInt32.self) == SnapshotFormat.magic else {
            throw SnapshotError.invalidMagic
        }
        let version = try reader.read(UInt32.self)
        guard version == SnapshotFormat.version else {
            throw SnapshotError.unsupportedVersion(version)
        }

        let documentCount = Int(try reader.read(UInt32.self))
        let termCount = Int(try reader.read(UInt32.self))
        let totalTokens = Int(try reader.read(UInt64.self))

        var documents: [DocumentRecord] = []
        documents.reserveCapacity(documentCount)
        for _ in 0..<documentCount {
            let tokenCount = Int(try reader.read(UInt32.self))
            let path = try reader.readString()
            documents.append(DocumentRecord(url: URL(filePath: path), tokenCount: tokenCount))
        }

        var vocabulary: [String: (offset: Int, count: Int)] = [:]
        vocabulary.reserveCapacity(termCount)
        for _ in 0..<termCount {
            let term = try reader.readString()
            let offset = Int(try reader.read(UInt64.self))
            let count = Int(try reader.read(UInt32.self))
            vocabulary[term] = (offset, count)
        }

        let postingsOffset = reader.position
        let postingsLength = data.count - postingsOffset

        let mapped = try MappedPostings(fileDescriptor: descriptor,
                                        offset: postingsOffset,
                                        length: postingsLength)

        return PersistedIndex(documents: documents,
                              vocabulary: vocabulary,
                              postings: mapped,
                              totalTokens: totalTokens)
    }
}

/// Read-only index backed by a memory-mapped postings block.
nonisolated struct PersistedIndex: Sendable {

    let documents: [DocumentRecord]
    let vocabulary: [String: (offset: Int, count: Int)]
    let postings: MappedPostings
    let totalTokens: Int

    var documentCount: Int { documents.count }
    var vocabularySize: Int { vocabulary.count }
    var averageDocumentLength: Double {
        documents.isEmpty ? 0 : Double(totalTokens) / Double(documents.count)
    }

    func postings(for term: String) -> [Posting] {
        guard let entry = vocabulary[term] else { return [] }
        return postings.postings(atByteOffset: entry.offset, count: entry.count)
    }
}