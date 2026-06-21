//
//  LocationStore.swift
//  MobileBackupSync
//
//  Created on 2026-06-21.
//

import Foundation

/// Persistiert die ausgewählte Quelle und das Ziel über App-Neustarts hinweg.
///
/// Lokale Ordner werden als **Security-Scoped Bookmark** gespeichert (eine rohe
/// `UIDocumentPicker`-URL überlebt einen Neustart nicht). SMB-Ziele werden als
/// JSON gesichert; das Passwort liegt weiterhin nur im Keychain.
final class LocationStore {
    static let shared = LocationStore()
    private init() {}

    /// Slot, für den ein Speicherort gemerkt wird.
    enum Slot: String {
        case source
        case destination
    }

    private let defaults = UserDefaults.standard

    // MARK: - Speichern

    func save(_ location: StorageLocation?, for slot: Slot) {
        guard let location else {
            defaults.removeObject(forKey: slot.rawValue)
            return
        }
        switch location {
        case .local(let url):
            if let data = makeBookmark(for: url) {
                defaults.set(Persisted.local(bookmark: data).encoded, forKey: slot.rawValue)
            }
        case .smb(let config):
            defaults.set(Persisted.smb(config).encoded, forKey: slot.rawValue)
        case .ftp(let config):
            defaults.set(Persisted.ftp(config).encoded, forKey: slot.rawValue)
        }
    }

    // MARK: - Laden

    func load(_ slot: Slot) -> StorageLocation? {
        guard let raw = defaults.data(forKey: slot.rawValue),
              let persisted = Persisted(encoded: raw) else { return nil }

        switch persisted {
        case .local(let bookmark):
            guard let url = resolve(bookmark, for: slot) else { return nil }
            return .local(url)
        case .smb(let config):
            return .smb(config)
        case .ftp(let config):
            return .ftp(config)
        }
    }

    // MARK: - Bookmark-Hilfen

    private func makeBookmark(for url: URL) -> Data? {
        // Bookmark-Erstellung braucht aktiven Zugriff auf die security-scoped URL.
        let didStart = url.startAccessingSecurityScopedResource()
        defer { if didStart { url.stopAccessingSecurityScopedResource() } }
        return try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
    }

    private func resolve(_ data: Data, for slot: Slot) -> URL? {
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: [],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else { return nil }

        // Veraltetes Bookmark auffrischen, solange die URL noch auflösbar ist.
        if isStale, let refreshed = makeBookmark(for: url) {
            defaults.set(Persisted.local(bookmark: refreshed).encoded, forKey: slot.rawValue)
        }
        return url
    }
}

// MARK: - Persistenz-Repräsentation

private enum Persisted: Codable {
    case local(bookmark: Data)
    case smb(SMBConfig)
    case ftp(FTPConfig)

    var encoded: Data { (try? JSONEncoder().encode(self)) ?? Data() }

    init?(encoded: Data) {
        guard let value = try? JSONDecoder().decode(Persisted.self, from: encoded) else { return nil }
        self = value
    }
}
