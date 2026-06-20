//
//  StorageProvider.swift
//  MobileBackupSync
//
//  Created on 2026-06-21.
//

import Foundation

/// Protokoll für alle Storage-Provider
protocol StorageProvider: Sendable {
    /// Verbindung herstellen
    func connect() async throws
    
    /// Verbindung trennen
    func disconnect() async
    
    /// Dateien auflisten
    func listContents(at path: String) async throws -> [FileItem]
    
    /// Datei lesen
    func readFile(at path: String) async throws -> Data
    
    /// Datei schreiben
    func writeFile(data: Data, to path: String, progress: @Sendable @escaping (Double) -> Void) async throws
    
    /// Datei löschen
    func deleteFile(at path: String) async throws
    
    /// Ordner erstellen
    func createDirectory(at path: String) async throws
    
    /// Metadaten lesen
    func getMetadata(for path: String) async throws -> FileItem
    
    /// Hash berechnen (optional, server-seitig wenn unterstützt)
    func calculateHash(for path: String) async throws -> String
    
    /// Freier Speicherplatz
    func getFreeSpace() async throws -> Int64
    
    /// Verbindungstest
    func testConnection() async -> Bool
}

/// Fehler des Storage-Providers
enum StorageProviderError: Error {
    case notConnected
    case notFound(String)
    case permissionDenied(String)
    case networkError(String)
    case timeout
    case unsupported(String)
    case other(String)
}
