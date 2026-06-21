//
//  HashService.swift
//  MobileBackupSync
//
//  Created on 2026-06-21.
//

import Foundation
import CryptoKit

/// Service für Hash-Berechnungen
class HashService {
    
    /// SHA-256 Hash für Data berechnen
    func sha256(for data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    /// SHA-256 Hash für Datei berechnen (chunked für große Dateien)
    func sha256(for url: URL) async throws -> String {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: url.path) else {
            throw HashError.fileNotFound
        }
        
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        
        var hasher = SHA256()
        let chunkSize = 1024 * 1024 // 1MB Chunks
        
        while let data = try handle.read(upToCount: chunkSize), !data.isEmpty {
            hasher.update(data: data)
        }
        
        let hash = hasher.finalize()
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    /// MD5 Hash für Data berechnen (schneller, aber weniger sicher)
    func md5(for data: Data) -> String {
        // MD5 ist in CryptoKit nicht verfügbar, verwenden wir CommonCrypto
        // Für MVP reicht SHA-256
        return sha256(for: data)
    }
    
    /// Zwei Dateien vergleichen über Hash
    func filesAreEqual(_ url1: URL, _ url2: URL) async throws -> Bool {
        let hash1 = try await sha256(for: url1)
        let hash2 = try await sha256(for: url2)
        return hash1 == hash2
    }
    
    /// Hash für Provider-Pfad berechnen (unterstützt server-seitiges Hashing wenn verfügbar)
    func calculateHash(for path: String, provider: any StorageProvider) async throws -> String {
        // Wenn der Provider server-seitiges Hashing unterstützt, verwenden
        // Ansonsten Datei herunterladen und lokal hashen
        
        // TODO: SSH Provider kann server-seitig hashen
        // SMB und Local müssen lokal hashen
        
        return try await provider.calculateHash(for: path)
    }
}

/// Hash-Fehler
enum HashError: Error {
    case fileNotFound
    case readError
    case invalidData
    
    var localizedDescription: String {
        switch self {
        case .fileNotFound: return "Datei nicht gefunden"
        case .readError: return "Lesefehler"
        case .invalidData: return "Ungültige Daten"
        }
    }
}

// MARK: - Data Extension

extension Data {
    var sha256: String {
        let hash = SHA256.hash(data: self)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    var md5: String {
        // Placeholder - für echte MD5 Implementation CommonCrypto verwenden
        sha256
    }
}
