//
//  SearchModel.swift
//  Rastro
//
//  Created by JoseAlvarez on 9/10/26.
//


import Foundation
import Observation

@MainActor
@Observable
final class SearchModel {

    enum State: Equatable {
        case idle
        case indexing(completed: Int, total: Int)
        case ready(documents: Int, terms: Int)
        case failed(String)
    }

    private(set) var state: State = .idle
    private(set) var results: [SearchResult] = []
    var query: String = ""

    private let store = IndexStore()
    private let tokenizer = Tokenizer()
    private var searchTask: Task<Void, Never>?

    var indexedFolder: URL?

    func restoreSavedFolder() {
        indexedFolder = FolderAccess.restore()
    }

    func chooseFolder() {
        guard let url = FolderPicker.chooseFolder() else { return }
        do {
            try FolderAccess.remember(url)
            indexedFolder = url
        } catch {
            state = .failed("Could not save folder access.")
        }
    }

    func buildIndex() async {
        guard let folder = indexedFolder else { return }
        state = .indexing(completed: 0, total: 0)

        await FolderAccess.withAccess(to: folder) {
            await IndexBuilder(tokenizer: tokenizer)
                .build(at: folder, into: store) { [weak self] completed, total in
                    Task { @MainActor in
                        self?.state = .indexing(completed: completed, total: total)
                    }
                }
        }

        let statistics = await store.statistics
        state = .ready(documents: statistics.documentCount,
                       terms: statistics.vocabularySize)
    }

    /// Debounced so typing does not queue one search per keystroke.
    func search() {
        searchTask?.cancel()
        let terms = tokenizer.tokens(in: query)

        guard !terms.isEmpty else {
            results = []
            return
        }

        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            let found = await store.search(terms: terms, limit: 20)
            guard !Task.isCancelled else { return }
            results = found
        }
    }
}