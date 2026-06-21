//
//  LocalStorageProvider.swift
//  MobileBackupSync
//
//  Created on 2026-06-21.
//

import Foundation

/// Provider für lokalen Dateisystem-Zugriff (iOS Files App).
///
/// Die Wurzel ist eine security-scoped URL aus dem `UIDocumentPicker`. Der
/// Zugriff wird in `connect()` geöffnet und in `disconnect()` wieder freigegeben,
/// damit er während des gesamten Sync-Laufs gültig bleibt.
final class LocalStorageProvider: StorageProvider {

    private let root: URL
    private var isAccessing = false

    init(root: URL) {
        self.root = root
    }

    func connect() async throws {
        // Security-scoped Zugriff öffnen (für Picker-URLs außerhalb der Sandbox).
        isAccessing = root.startAccessingSecurityScopedResource()
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: root.path, isDirectory: &isDir), isDir.boolValue else {
            throw StorageProviderError.notFound(root.path)
        }
    }

    func disconnect() async {
        if isAccessing {
            root.stopAccessingSecurityScopedResource()
            isAccessing = false
        }
    }

    func listFiles() async throws -> [FileItem] {
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.isDirectoryKey, .contentModificationDateKey, .fileSizeKey]

        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            throw StorageProviderError.notFound(root.path)
        }

        var items: [FileItem] = []
        while let url = enumerator.nextObject() as? URL {
            let values = try url.resourceValues(forKeys: Set(keys))
            if values.isDirectory == true { continue } // nur Dateien

            items.append(FileItem(
                name: url.lastPathComponent,
                path: url.path,
                relativePath: Self.relativePath(of: url, under: root),
                isDirectory: false,
                size: Int64(values.fileSize ?? 0),
                modifiedDate: values.contentModificationDate ?? Date()
            ))
        }
        return items
    }

    func readData(at relativePath: String) async throws -> Data {
        let url = root.appendingPathComponent(relativePath)
        guard let data = try? Data(contentsOf: url) else {
            throw StorageProviderError.notFound(relativePath)
        }
        return data
    }

    func upload(from localURL: URL, to relativePath: String,
                progress: @escaping (Double) -> Void) async throws {
        let target = root.appendingPathComponent(relativePath)
        let fm = FileManager.default
        try fm.createDirectory(at: target.deletingLastPathComponent(),
                               withIntermediateDirectories: true)
        if fm.fileExists(atPath: target.path) {
            try fm.removeItem(at: target)
        }
        try fm.copyItem(at: localURL, to: target)
        progress(1.0)
    }

    func download(at relativePath: String, to localURL: URL,
                  progress: @escaping (Double) -> Void) async throws {
        let source = root.appendingPathComponent(relativePath)
        let fm = FileManager.default
        if fm.fileExists(atPath: localURL.path) {
            try fm.removeItem(at: localURL)
        }
        try fm.copyItem(at: source, to: localURL)
        progress(1.0)
    }

    func delete(at relativePath: String) async throws {
        let url = root.appendingPathComponent(relativePath)
        try FileManager.default.removeItem(at: url)
    }

    func setModificationDate(_ date: Date, at relativePath: String) async {
        let url = root.appendingPathComponent(relativePath)
        try? FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: url.path)
    }

    func getFreeSpace() async throws -> Int64 {
        let values = try root.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return values.volumeAvailableCapacityForImportantUsage ?? Int64.max
    }

    func testConnection() async -> Bool {
        do {
            try await connect()
            await disconnect()
            return true
        } catch {
            return false
        }
    }

    /// Pfad von `url` relativ zu `base` (POSIX, ohne führenden Slash).
    static func relativePath(of url: URL, under base: URL) -> String {
        let baseComponents = base.standardizedFileURL.pathComponents
        let urlComponents = url.standardizedFileURL.pathComponents
        guard urlComponents.count > baseComponents.count,
              Array(urlComponents.prefix(baseComponents.count)) == baseComponents else {
            return url.lastPathComponent
        }
        return urlComponents.dropFirst(baseComponents.count).joined(separator: "/")
    }
}
