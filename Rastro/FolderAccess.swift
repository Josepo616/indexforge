//
//  FolderAccess.swift
//  Rastro
//
//  Created by JoseAlvarez on 9/10/26.
//


import Foundation

/// Persists user-granted folder access across launches.
///
/// The sandbox forgets a granted folder when the app quits. A security-scoped
/// bookmark is the receipt that lets us reclaim it without asking again.
nonisolated struct FolderAccess: Sendable {

    private static let defaultsKey = "indexedFolderBookmark"

    /// Stores the bookmark for a folder the user just picked.
    static func remember(_ url: URL) throws {
        let bookmark = try url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        UserDefaults.standard.set(bookmark, forKey: defaultsKey)
    }

    /// Resolves the stored bookmark, refreshing it if the system reports it stale.
    static func restore() -> URL? {
        guard let bookmark = UserDefaults.standard.data(forKey: defaultsKey) else {
            return nil
        }

        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: bookmark,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            UserDefaults.standard.removeObject(forKey: defaultsKey)
            return nil
        }

        // A stale bookmark still resolves once. Refresh it now or lose it later.
        if isStale {
            _ = try? remember(url)
        }
        return url
    }

    static func forget() {
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }

    /// Runs `body` with security scope held, releasing it on every path.
    static func withAccess<T>(to url: URL, _ body: () async throws -> T) async rethrows -> T {
        let granted = url.startAccessingSecurityScopedResource()
        defer { if granted { url.stopAccessingSecurityScopedResource() } }
        return try await body()
    }
}