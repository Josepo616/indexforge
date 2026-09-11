//
//  Highlighter.swift
//  Rastro
//
//  Created by JoseAlvarez on 9/10/26.
//


import SwiftUI

/// Highlights query matches in display text.
///
/// Matching runs through the same tokenizer as the index, so folded forms
/// line up: searching "cafe" highlights "Café", exactly as the ranking scored it.
nonisolated struct Highlighter: Sendable {

    let tokenizer: Tokenizer

    func highlight(_ text: String, matching terms: [String]) -> AttributedString {
        var attributed = AttributedString(text)
        guard !terms.isEmpty else { return attributed }

        let wanted = Set(terms)

        for range in matchingRanges(in: text, terms: wanted) {
            guard let lower = AttributedString.Index(range.lowerBound, within: attributed),
                  let upper = AttributedString.Index(range.upperBound, within: attributed)
            else { continue }

            attributed[lower..<upper].backgroundColor = .yellow
            attributed[lower..<upper].foregroundColor = .black
        }
        return attributed
    }

    /// Walks the raw text token by token, folding each candidate the same way
    /// the tokenizer does, and keeps the ranges whose folded form is a match.
    private func matchingRanges(in text: String,
                                terms: Set<String>) -> [Range<String.Index>] {

        var ranges: [Range<String.Index>] = []
        var start: String.Index?
        var index = text.startIndex

        func close(at end: String.Index) {
            guard let begin = start else { return }
            start = nil
            let candidate = String(text[begin..<end])
            for token in tokenizer.tokens(in: candidate) where terms.contains(token) {
                ranges.append(begin..<end)
                break
            }
        }

        while index < text.endIndex {
            let isWord = text[index].unicodeScalars.allSatisfy {
                $0.properties.isAlphabetic || ($0.value >= 48 && $0.value <= 57)
            }

            if isWord {
                if start == nil { start = index }
            } else {
                close(at: index)
            }
            index = text.index(after: index)
        }
        close(at: text.endIndex)

        return ranges
    }
}