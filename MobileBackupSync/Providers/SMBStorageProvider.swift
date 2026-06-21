//
//  SMBStorageProvider.swift
//  MobileBackupSync
//
//  Created on 2026-06-21.
//

import Foundation
import AMSMB2

/// Provider für SMB/CIFS-Netzwerkfreigaben.
/// Basiert auf AMSMB2 (libsmb2). Alle Pfade sind relativ zu `config.path`
/// innerhalb der verbundenen Freigabe.
final class SMBStorageProvider: StorageProvider {

    private let config: SMBConfig
    private let rootPath: String
    private var manager: SMB2Manager?

    init(config: SMBConfig) {
        self.config = config
        self.rootPath = Self.normalize(config.path)
    }

    // MARK: - Verbindung

    func connect() async throws {
        guard manager == nil else { return }

        guard let url = URL(string: "smb://\(config.host)") else {
            throw StorageProviderError.networkError("Ungültige Server-Adresse")
        }

        let user = config.username.isEmpty ? "guest" : config.username
        // Passwort aus dem Keychain laden (leer für Gast-Zugang).
        let password = config.username.isEmpty
            ? ""
            : (SettingsStore.shared.getSMBPassword(host: config.host, username: config.username) ?? "")
        let credential = URLCredential(user: user, password: password, persistence: .forSession)

        guard let mgr = SMB2Manager(url: url, credential: credential) else {
            throw StorageProviderError.networkError("SMB-Client konnte nicht initialisiert werden")
        }

        // Signing erzwingen für FRITZ!Box-Kompatibilität.
        mgr.forceSMBSigning = true
        mgr.verboseWireLog = false

        do {
            try await mgr.connectShare(name: config.share, encrypted: false)
            self.manager = mgr
        } catch {
            throw StorageProviderError.networkError("Verbindung fehlgeschlagen: \(error.localizedDescription)")
        }
    }

    func disconnect() async {
        try? await manager?.disconnectShare(gracefully: true)
        manager = nil
    }

    // MARK: - Auflisten

    func listFiles() async throws -> [FileItem] {
        let manager = try requireManager()
        do {
            let entries = try await manager.contentsOfDirectory(atPath: rootPath, recursive: true)
            return entries.compactMap { entry -> FileItem? in
                let isDir = (entry[.fileResourceTypeKey] as? URLFileResourceType) == .directory
                    || (entry[.isDirectoryKey] as? Bool) == true
                if isDir { return nil } // nur Dateien

                guard let fullPath = entry[.pathKey] as? String else { return nil }
                let normalizedFull = Self.normalize(fullPath)
                let name = (entry[.nameKey] as? String) ?? (normalizedFull as NSString).lastPathComponent

                let size = (entry[.fileSizeKey] as? NSNumber)?.int64Value ?? 0
                let modified = entry[.contentModificationDateKey] as? Date ?? Date()

                return FileItem(
                    name: name,
                    path: normalizedFull,
                    relativePath: Self.relative(normalizedFull, to: rootPath),
                    isDirectory: false,
                    size: size,
                    modifiedDate: modified
                )
            }
        } catch {
            throw StorageProviderError.networkError("Auflisten fehlgeschlagen: \(error.localizedDescription)")
        }
    }

    // MARK: - Lesen / Schreiben

    func readData(at relativePath: String) async throws -> Data {
        let manager = try requireManager()
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: temp) }
        do {
            try await manager.downloadItem(atPath: fullPath(for: relativePath), to: temp, progress: nil)
            return try Data(contentsOf: temp)
        } catch {
            throw StorageProviderError.networkError("Download fehlgeschlagen: \(error.localizedDescription)")
        }
    }

    func upload(from localURL: URL, to relativePath: String,
                progress: @escaping (Double) -> Void) async throws {
        let manager = try requireManager()
        let remote = fullPath(for: relativePath)
        try await ensureParentDirectory(of: remote, manager: manager)

        let totalBytes = Int64(localURL.fileSizeOrZero)
        do {
            try await manager.uploadItem(at: localURL, toPath: remote) { written in
                if totalBytes > 0 { progress(min(1.0, Double(written) / Double(totalBytes))) }
                return true
            }
            progress(1.0)
        } catch {
            throw StorageProviderError.networkError("Upload fehlgeschlagen: \(error.localizedDescription)")
        }
    }

    func download(at relativePath: String, to localURL: URL,
                  progress: @escaping (Double) -> Void) async throws {
        let manager = try requireManager()
        let fm = FileManager.default
        if fm.fileExists(atPath: localURL.path) { try fm.removeItem(at: localURL) }
        do {
            try await manager.downloadItem(atPath: fullPath(for: relativePath), to: localURL) { read, total in
                if total > 0 { progress(min(1.0, Double(read) / Double(total))) }
                return true
            }
            progress(1.0)
        } catch {
            throw StorageProviderError.networkError("Download fehlgeschlagen: \(error.localizedDescription)")
        }
    }

    func delete(at relativePath: String) async throws {
        let manager = try requireManager()
        do {
            try await manager.removeItem(atPath: fullPath(for: relativePath))
        } catch {
            throw StorageProviderError.networkError("Löschen fehlgeschlagen: \(error.localizedDescription)")
        }
    }

    func setModificationDate(_ date: Date, at relativePath: String) async {
        guard let manager else { return }
        // SetInfo am Ziel; Fehler hier sind nicht fatal (Abgleich kopiert dann
        // ggf. erneut), daher nur best effort.
        try? await manager.setAttributes(
            attributes: [.contentModificationDateKey: date],
            ofItemAtPath: fullPath(for: relativePath)
        )
    }

    func getFreeSpace() async throws -> Int64 {
        let manager = try requireManager()
        guard let attrs = try? await manager.attributesOfFileSystem(forPath: rootPath.isEmpty ? "/" : rootPath),
              let free = (attrs[.systemFreeSize] as? NSNumber)?.int64Value else {
            return Int64.max
        }
        return free
    }

    func testConnection() async -> Bool {
        do {
            try await connect()
            _ = try await contentsAtRoot()
            await disconnect()
            return true
        } catch {
            return false
        }
    }

    // MARK: - Helfer

    private func requireManager() throws -> SMB2Manager {
        guard let manager else { throw StorageProviderError.notConnected }
        return manager
    }

    private func contentsAtRoot() async throws -> [[URLResourceKey: Any]] {
        let manager = try requireManager()
        return try await manager.contentsOfDirectory(atPath: rootPath, recursive: false)
    }

    /// Vollständiger SMB-Pfad aus Wurzel + relativem Pfad.
    private func fullPath(for relativePath: String) -> String {
        let rel = Self.normalize(relativePath)
        if rootPath.isEmpty { return rel }
        return rel.isEmpty ? rootPath : "\(rootPath)/\(rel)"
    }

    /// Legt fehlende Elternverzeichnisse eines Remote-Pfads an.
    private func ensureParentDirectory(of remotePath: String, manager: SMB2Manager) async throws {
        let parts = remotePath.split(separator: "/").dropLast()
        guard !parts.isEmpty else { return }
        var current = ""
        for part in parts {
            current = current.isEmpty ? String(part) : "\(current)/\(part)"
            // Existiert das Verzeichnis bereits, ignorieren wir den Fehler.
            try? await manager.createDirectory(atPath: current)
        }
    }

    /// Normalisiert Pfade für SMB (Backslashes, doppelte/umschließende Slashes).
    static func normalize(_ path: String) -> String {
        var p = path.replacingOccurrences(of: "\\", with: "/")
        while p.contains("//") { p = p.replacingOccurrences(of: "//", with: "/") }
        while p.hasPrefix("/") { p.removeFirst() }
        while p.hasSuffix("/") { p.removeLast() }
        return p
    }

    /// `fullPath` relativ zu `base` (beide bereits normalisiert).
    static func relative(_ fullPath: String, to base: String) -> String {
        guard !base.isEmpty else { return fullPath }
        if fullPath == base { return "" }
        let prefix = base + "/"
        return fullPath.hasPrefix(prefix) ? String(fullPath.dropFirst(prefix.count)) : fullPath
    }
}

private extension URL {
    var fileSizeOrZero: Int {
        (try? resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
    }
}
