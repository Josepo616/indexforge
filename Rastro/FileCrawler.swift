//
//  FileCrawler.swift
//  Rastro
//
//  Created by JoseAlvarez on 9/9/26.
//

import Foundation

nonisolated struct FileCrawler: Sendable {

    let allowedExtensions: Set<String>
    let maximumFileSize: Int

    init(allowedExtensions: Set<String> = ["txt", "md", "swift", "json", "csv"],
         maximumFileSize: Int = 4 * 1024 * 1024) {
        self.allowedExtensions = allowedExtensions
        self.maximumFileSize = maximumFileSize
    }

    /// Walks the tree once. Cheap compared to parsing, and gives us a total
    /// up front so progress can be reported as a percentage.
    func collectFiles(at root: URL) -> [URL] {
        let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey]

        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        var results: [URL] = []

        for case let url as URL in enumerator {
            guard allowedExtensions.contains(url.pathExtension.lowercased()) else { continue }
            guard let values = try? url.resourceValues(forKeys: Set(keys)),
                  values.isRegularFile == true,
                  let size = values.fileSize,
                  size <= maximumFileSize
            else { continue }

            results.append(url)
        }

        return results
    }
}
