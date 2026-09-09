//
//  Tokenizer.swift
//  Rastro
//
//  Created by JoseAlvarez on 8/31/26.
//

import Foundation

nonisolated struct Tokenizer: Sendable {
    let minimumLength: Int
    let stopWords: Set<String>

    init(
        minimumLength: Int = 2,
        stopWords: Set<String> = Tokenizer.defaultStopWords
    ) {
        self.minimumLength = minimumLength
        self.stopWords = stopWords
    }

    /// Locate fixed: Make the folding deterministic between machines
    private static let foldingLocale: Locale = .init(identifier: "en_US_POSIX")

    /// Emit every toke by callback, does not accumulate
    func tokenize(_ text: String, _ emit: (String) -> Void) {
        let folded = text.folding(
            options: [.diacriticInsensitive, .caseInsensitive],
            locale: Tokenizer.foldingLocale
        )

        var buffer = String.UnicodeScalarView()
        buffer.reserveCapacity(32)

        for scalar in folded.unicodeScalars {
            if Tokenizer.isTokenScalar(scalar) {
                buffer.append(scalar)
            } else {
                flush(&buffer, emit)
            }
        }
        flush(&buffer, emit)
    }

    /// Convenient for tests, do not use in the hot path
    func tokens(in text: String) -> [String] {
        var result: [String] = []
        tokenize(text) { result.append($0) }
        return result
    }

    private func flush(
        _ buffer: inout String.UnicodeScalarView,
        _ emit: (String) -> Void
    ) {
        defer { buffer.removeAll(keepingCapacity: true) }
        guard buffer.count >= minimumLength else { return }
        let token = String(buffer)
        guard !stopWords.contains(token) else { return }
        emit(token)
    }

    private static func isTokenScalar(_ scalar: Unicode.Scalar) -> Bool {
        scalar.properties.isAlphabetic
            || scalar.value >= 48 && scalar.value <= 57
    }
}

extension Tokenizer {
    /// minimum list ES/EN, check BM25
    static let defaultStopWords: Set<String> = [
        "de", "la", "que", "el", "en", "los", "se", "las", "por",
        "con", "no", "una", "su", "para", "es", "al", "lo", "como",
        "the", "of", "and", "to", "in", "is", "it", "for", "on",
        "with", "as", "at", "by", "an", "be", "this", "that",
    ]
}
