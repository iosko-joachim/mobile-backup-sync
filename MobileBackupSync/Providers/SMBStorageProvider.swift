//
//  SMBStorageProvider.swift
//  MobileBackupSync
//
//  Created on 2026-06-21.
//

import Foundation
import AMSMB2

/// Provider für SMB/CIFS Netzwerkfreigaben
/// Basierend auf AMSMB2 (libsmb2) - adaptiert vom NAS-backup Projekt
class SMBStorageProvider: StorageProvider {
    
    private let config: SMBConfig
    private var isConnected = false
    private var manager: SMB2Manager?
    
    init(config: SMBConfig) {
        self.config = config
    }
    
    deinit {
        Task { @MainActor in
            await disconnect()
        }
    }
    
    /// SMB Verbindung herstellen
    func connect() async throws {
        guard !isConnected else { return }
        
        guard let url = URL(string: "smb://\(config.host)") else {
            throw StorageProviderError.networkError("Ungültige Server-Adresse")
        }
        
        let user = config.username.isEmpty ? "guest" : config.username
        let credential = URLCredential(user: user, password: "", persistence: .forSession)
        
        guard let mgr = SMB2Manager(url: url, credential: credential) else {
            throw StorageProviderError.networkError("SMB-Client konnte nicht initialisiert werden")
        }
        
        // Signing erzwingen für FRITZ!Box Kompatibilität
        mgr.forceSMBSigning = true
        mgr.verboseWireLog = false
        
        do {
            try await mgr.connectShare(name: config.share, encrypted: false)
            self.manager = mgr
            self.isConnected = true
        } catch {
            throw StorageProviderError.networkError("SMB Connect fehlgeschlagen: \(error.localizedDescription)")
        }
    }
    
    /// Verbindung trennen
    func disconnect() async {
        try? await manager?.disconnectShare(gracefully: true)
        manager = nil
        isConnected = false
    }
    
    /// Dateien in einem Verzeichnis auflisten
    func listContents(at path: String) async throws -> [FileItem] {
        guard let manager, isConnected else {
            throw StorageProviderError.notConnected
        }
        
        let normalizedPath = Self.normalize(path)
        
        do {
            let entries = try await manager.contentsOfDirectory(atPath: normalizedPath, recursive: false)
            
            return entries.compactMap { e -> FileItem? in
                guard let name = e[.nameKey] as? String,
                      name != ".", name != ".." else { return nil }
                
                let isDir = (e[.fileResourceTypeKey] as? URLFileResourceType) == .directory
                    || (e[.isDirectoryKey] as? Bool) == true
                
                let size = (e[.fileSizeKey] as? NSNumber)?.int64Value ?? 0
                let modifiedDate = e[.contentModificationDateKey] as? Date ?? Date()
                
                let fullPath = normalizedPath.isEmpty ? name : "\(normalizedPath)/\(name)"
                
                return FileItem(
                    name: name,
                    path: fullPath,
                    isDirectory: isDir,
                    size: size,
                    modifiedDate: modifiedDate
                )
            }
        } catch {
            throw StorageProviderError.networkError("Listing fehlgeschlagen: \(error.localizedDescription)")
        }
    }
    
    /// Remote Datei als Data lesen
    func readFile(at path: String) async throws -> Data {
        guard let manager, isConnected else {
            throw StorageProviderError.notConnected
        }
        
        let normalizedPath = Self.normalize(path)
        let tempDir = FileManager.default.temporaryDirectory
        let localURL = tempDir.appendingPathComponent(UUID().uuidString)
        
        do {
            try await manager.downloadItem(atPath: normalizedPath, to: localURL, progress: nil)
            let data = try Data(contentsOf: localURL)
            try? FileManager.default.removeItem(at: localURL)
            return data
        } catch {
            throw StorageProviderError.networkError("Download fehlgeschlagen: \(error.localizedDescription)")
        }
    }
    
    /// Datei auf SMB Server schreiben
    func writeFile(data: Data, to path: String, progress: @Sendable @escaping (Double) -> Void) async throws {
        guard let manager, isConnected else {
            throw StorageProviderError.notConnected
        }
        
        let normalizedPath = Self.normalize(path)
        let tempDir = FileManager.default.temporaryDirectory
        let localURL = tempDir.appendingPathComponent(UUID().uuidString)
        
        // Daten temporär schreiben
        try data.write(to: localURL)
        defer { try? FileManager.default.removeItem(at: localURL) }
        
        do {
            try await manager.uploadItem(at: localURL, toPath: normalizedPath) { bytesWritten in
                // AMSMB2 liefert nur bytesWritten, nicht totalBytes
                // Wir müssen den Fortschritt selbst berechnen
                let totalBytes = Int64(data.count)
                let p = totalBytes > 0 ? Double(bytesWritten) / Double(totalBytes) : 0
                progress(p)
                return true // Continue
            }
        } catch {
            throw StorageProviderError.networkError("Upload fehlgeschlagen: \(error.localizedDescription)")
        }
    }
    
    /// Remote Datei löschen
    func deleteFile(at path: String) async throws {
        guard let manager, isConnected else {
            throw StorageProviderError.notConnected
        }
        
        let normalizedPath = Self.normalize(path)
        
        // AMSMB2 hat keine direkte deleteItem Methode
        // Wir müssen die Datei über einen leeren Upload überschreiben oder einen anderen Weg finden
        // Für jetzt als "unsupported" markieren
        throw StorageProviderError.unsupported("Löschen von Dateien wird aktuell nicht unterstützt")
    }
    
    /// Remote Ordner erstellen
    func createDirectory(at path: String) async throws {
        guard let manager, isConnected else {
            throw StorageProviderError.notConnected
        }
        
        let normalizedPath = Self.normalize(path)
        
        do {
            try await manager.createDirectory(atPath: normalizedPath)
        } catch {
            throw StorageProviderError.networkError("Verzeichnis erstellen fehlgeschlagen: \(error.localizedDescription)")
        }
    }
    
    /// Metadaten für Remote Datei lesen
    func getMetadata(for path: String) async throws -> FileItem {
        guard let manager, isConnected else {
            throw StorageProviderError.notConnected
        }
        
        let normalizedPath = Self.normalize(path)
        
        // Hole Parent-Verzeichnis und suche die Datei darin
        let parentPath: String
        let fileName: String
        
        if let lastSlash = normalizedPath.lastIndex(of: "/") {
            parentPath = String(normalizedPath[..<lastSlash])
            fileName = String(normalizedPath[normalizedPath.index(after: lastSlash)...])
        } else {
            parentPath = ""
            fileName = normalizedPath
        }
        
        let entries: [[URLResourceKey: Any]]
        do {
            entries = try await manager.contentsOfDirectory(atPath: parentPath.isEmpty ? "/" : parentPath, recursive: false)
        } catch {
            throw StorageProviderError.notFound(path)
        }
        
        guard let entry = entries.first(where: { ($0[.nameKey] as? String) == fileName }) else {
            throw StorageProviderError.notFound(path)
        }
        
        let isDir = (entry[.fileResourceTypeKey] as? URLFileResourceType) == .directory
        let size = (entry[.fileSizeKey] as? NSNumber)?.int64Value ?? 0
        let modifiedDate = entry[.contentModificationDateKey] as? Date ?? Date()
        
        return FileItem(
            name: fileName,
            path: path,
            isDirectory: isDir,
            size: size,
            modifiedDate: modifiedDate
        )
    }
    
    /// Hash berechnen (client-seitig, da SMB kein server-seitiges Hashing unterstützt)
    func calculateHash(for path: String) async throws -> String {
        let data = try await readFile(at: path)
        return data.sha256
    }
    
    /// Freier Speicherplatz auf SMB Server
    func getFreeSpace() async throws -> Int64 {
        guard let manager, isConnected else {
            throw StorageProviderError.notConnected
        }
        
        // AMSMB2 bietet keine direkte Methode für freien Speicherplatz
        // Rückgabe von max als Placeholder
        return Int64.max
    }
    
    /// SMB Verbindung testen
    func testConnection() async -> Bool {
        do {
            try await connect()
            _ = try await listContents(at: "/")
            await disconnect()
            return true
        } catch {
            return false
        }
    }
    
    /// SMB Session neu verbinden (für Retry-Logik)
    func reconnect() async throws {
        await disconnect()
        try await connect()
    }
    
    /// Normalisiert Pfade für SMB
    static func normalize(_ path: String) -> String {
        var p = path.replacingOccurrences(of: "\\", with: "/")
        while p.contains("//") { p = p.replacingOccurrences(of: "//", with: "/") }
        while p.hasPrefix("/") { p.removeFirst() }
        while p.hasSuffix("/") { p.removeLast() }
        return p
    }
}
