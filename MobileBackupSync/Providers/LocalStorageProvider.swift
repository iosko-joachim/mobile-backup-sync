//
//  LocalStorageProvider.swift
//  MobileBackupSync
//
//  Created on 2026-06-21.
//

import Foundation

/// Provider für lokalen Dateisystem-Zugriff (iOS Files App)
class LocalStorageProvider: StorageProvider {
    
    private var isConnected = true
    
    /// Verbindung herstellen (lokal immer verbunden)
    func connect() async throws {
        isConnected = true
    }
    
    /// Verbindung trennen
    func disconnect() async {
        isConnected = false
    }
    
    /// Dateien in einem Verzeichnis auflisten
    func listContents(at path: String) async throws -> [FileItem] {
        guard isConnected else {
            throw StorageProviderError.notConnected
        }
        
        let url = URL(fileURLWithPath: path)
        let fileManager = FileManager.default
        
        let contents = try fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [
                .isDirectoryKey,
                .contentModificationDateKey,
                .fileSizeKey
            ],
            options: [.skipsHiddenFiles]
        )
        
        return contents.compactMap { url in
            guard let attributes = try? fileManager.attributesOfItem(atPath: url.path),
                  let isDirectory = attributes[.type] as? String,
                  let modifiedDate = attributes[.modificationDate] as? Date else {
                return nil
            }
            
            let size = attributes[.size] as? Int64 ?? 0
            let isDir = isDirectory == "NSFileTypeDirectory"
            
            return FileItem(
                name: url.lastPathComponent,
                path: url.path,
                isDirectory: isDir,
                size: size,
                modifiedDate: modifiedDate
            )
        }
    }
    
    /// Datei als Data lesen
    func readFile(at path: String) async throws -> Data {
        guard isConnected else {
            throw StorageProviderError.notConnected
        }
        
        let url = URL(fileURLWithPath: path)
        guard let data = try? Data(contentsOf: url) else {
            throw StorageProviderError.notFound(path)
        }
        
        return data
    }
    
    /// Datei schreiben
    func writeFile(data: Data, to path: String, progress: @Sendable @escaping (Double) -> Void) async throws {
        guard isConnected else {
            throw StorageProviderError.notConnected
        }
        
        let url = URL(fileURLWithPath: path)
        let parentDir = url.deletingLastPathComponent()
        
        // Verzeichnis erstellen falls nötig
        var isDirectory: ObjCBool = false
        if !FileManager.default.fileExists(atPath: parentDir.path, isDirectory: &isDirectory) {
            try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
        }
        
        // Datei schreiben (ohne echten Fortschritt für lokale Dateien)
        try data.write(to: url)
        progress(1.0)
    }
    
    /// Datei löschen
    func deleteFile(at path: String) async throws {
        guard isConnected else {
            throw StorageProviderError.notConnected
        }
        
        let url = URL(fileURLWithPath: path)
        try FileManager.default.removeItem(at: url)
    }
    
    /// Ordner erstellen
    func createDirectory(at path: String) async throws {
        guard isConnected else {
            throw StorageProviderError.notConnected
        }
        
        let url = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
    
    /// Metadaten für eine Datei lesen
    func getMetadata(for path: String) async throws -> FileItem {
        guard isConnected else {
            throw StorageProviderError.notConnected
        }
        
        let url = URL(fileURLWithPath: path)
        let fileManager = FileManager.default
        
        let attributes = try fileManager.attributesOfItem(atPath: path)
        guard let isDirectory = attributes[.type] as? String,
              let modifiedDate = attributes[.modificationDate] as? Date else {
            throw StorageProviderError.notFound(path)
        }
        
        let size = attributes[.size] as? Int64 ?? 0
        let isDir = isDirectory == "NSFileTypeDirectory"
        
        return FileItem(
            name: url.lastPathComponent,
            path: path,
            isDirectory: isDir,
            size: size,
            modifiedDate: modifiedDate
        )
    }
    
    /// Hash berechnen (client-seitig)
    func calculateHash(for path: String) async throws -> String {
        guard isConnected else {
            throw StorageProviderError.notConnected
        }
        
        let data = try await readFile(at: path)
        return data.sha256
    }
    
    /// Freier Speicherplatz
    func getFreeSpace() async throws -> Int64 {
        let fileManager = FileManager.default
        let paths = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        guard let documents = paths.first else { return 0 }
        
        guard let attributes = try? fileManager.attributesOfFileSystem(forPath: documents.path),
              let freeSpace = attributes[.systemFreeSize] as? Int64 else {
            return 0
        }
        
        return freeSpace
    }
    
    /// Verbindungstest (lokal immer erfolgreich)
    func testConnection() async -> Bool {
        true
    }
}
