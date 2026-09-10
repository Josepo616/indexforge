//
//  MappedPostings.swift
//  Rastro
//
//  Created by JoseAlvarez on 9/10/26.
//


import Foundation

/// A postings block mapped from disk. Pages load on demand.
///
/// `mmap` requires a page-aligned file offset, so we map from zero and keep
/// the logical offset ourselves. Mapping extra costs nothing: pages are only
/// faulted in when touched.
nonisolated final class MappedPostings: @unchecked Sendable {

    private let base: UnsafeRawPointer
    private let mappedLength: Int
    private let blockOffset: Int
    private let blockLength: Int

    init(fileDescriptor: Int32, offset: Int, length: Int) throws {
        guard length > 0, offset >= 0 else { throw SnapshotError.truncated }

        let total = offset + length
        guard let pointer = mmap(nil, total, PROT_READ, MAP_PRIVATE,
                                 fileDescriptor, 0),
              pointer != MAP_FAILED
        else { throw SnapshotError.mappingFailed(errno) }

        self.base = UnsafeRawPointer(pointer)
        self.mappedLength = total
        self.blockOffset = offset
        self.blockLength = length
    }

    deinit {
        munmap(UnsafeMutableRawPointer(mutating: base), mappedLength)
    }

    /// Reads `count` postings starting at `offset` bytes into the block.
    func postings(atByteOffset offset: Int, count: Int) -> [Posting] {
        guard offset >= 0, count >= 0, offset + count * 8 <= blockLength else {
            return []
        }
        var result: [Posting] = []
        result.reserveCapacity(count)
        for i in 0..<count {
            let entry = base + blockOffset + offset + i * 8
            result.append(Posting(
                document: DocumentID(littleEndian: entry.loadUnaligned(as: Int32.self)),
                frequency: Int32(littleEndian: entry.loadUnaligned(fromByteOffset: 4, as: Int32.self))
            ))
        }
        return result
    }
}
