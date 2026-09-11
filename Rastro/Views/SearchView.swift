//
//  SearchView.swift
//  Rastro
//
//  Created by JoseAlvarez on 9/10/26.
//


import SwiftUI

struct SearchView: View {
    @Bindable var model: SearchModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            TextField("Search", text: $model.query)
                .textFieldStyle(.roundedBorder)
                .onChange(of: model.query) { model.search() }

            Divider()

            List(model.results, id: \.url) { result in
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.highlighted(result.url.lastPathComponent))
                        .font(.body)
                    Text(model.highlighted(result.url.deletingLastPathComponent().path(percentEncoded: false)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.head)
                }
                .onTapGesture {
                    NSWorkspace.shared.activateFileViewerSelecting([result.url])
                }
            }
            .listStyle(.plain)
        }
        .padding(12)
        .task { model.restoreSavedFolder() }
    }

    @ViewBuilder
    private var header: some View {
        HStack {
            switch model.state {
            case .idle:
                Text(model.indexedFolder?.lastPathComponent ?? "No folder")
                    .foregroundStyle(.secondary)
            case .indexing(let completed, let total):
                ProgressView(value: Double(completed), total: Double(max(total, 1)))
                Text("\(completed)/\(total)").monospacedDigit()
            case .ready(let documents, let terms):
                Text("\(documents) docs · \(terms) terms")
                    .foregroundStyle(.secondary)
            case .failed(let message):
                Text(message).foregroundStyle(.red)
            }

            Spacer()

            Button("Folder…") { model.chooseFolder() }
            Button("Index") { Task { await model.buildIndex() } }
                .disabled(model.indexedFolder == nil)
        }
        .font(.callout)
    }
}

#Preview("Search View") {
    SearchView(
        model: SearchModel()
    )
}
