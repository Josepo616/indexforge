//
//  SnapshotError.swift
//  Rastro
//
//  Created by JoseAlvarez on 9/10/26.
//


import Foundation

enum SnapshotError: Error {
    case invalidMagic
    case unsupportedVersion(UInt32)
    case truncated
    case mappingFailed(Int32)
}

nonisolated enum SnapshotFormat {
    static let magic: UInt32 = 0x52535431   // "RST1"
    static let version: UInt32 = 1
}

/// Append-only byte buffer with fixed-width little-endian primitives.
nonisolated struct ByteWriter {
    private(set) var data = Data()

    mutating func write<T: FixedWidthInteger>(_ value: T) {
        var little = value.littleEndian
        withUnsafeBytes(of: &little) { data.append(contentsOf: $0) }
    }

    mutating func write(_ string: String) {
        let bytes = Array(string.utf8)
        write(UInt32(bytes.count))
        data.append(contentsOf: bytes)
    }
}

/// Cursor over a byte buffer. Bounds-checked on every read.
nonisolated struct ByteReader {
    private let data: Data
    private var offset: Int

    init(_ data: Data, offset: Int = 0) {
        self.data = data
        self.offset = offset
    }

    var position: Int { offset }

    mutating func read<T: FixedWidthInteger>(_ type: T.Type) throws -> T {
        let size = MemoryLayout<T>.size
        guard offset + size <= data.count else { throw SnapshotError.truncated }
        let value = data.withUnsafeBytes { buffer -> T in
            buffer.loadUnaligned(fromByteOffset: offset, as: T.self)
        }
        offset += size
        return T(littleEndian: value)
    }

    mutating func readString() throws -> String {
        let length = Int(try read(UInt32.self))
        guard offset + length <= data.count else { throw SnapshotError.truncated }
        let bytes = data.subdata(in: offset..<(offset + length))
        offset += length
        guard let string = String(data: bytes, encoding: .utf8) else {
            throw SnapshotError.truncated
        }
        return string
    }
}