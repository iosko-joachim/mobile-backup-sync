//
//  HashService.swift
//  MobileBackupSync
//
//  Created on 2026-06-21.
//

import Foundation
import CryptoKit

/// Service für SHA-256-Hash-Berechnungen.
struct HashService {

    /// SHA-256 für ein `Data`-Objekt.
    func sha256(for data: Data) -> String {
        data.sha256
    }

    /// SHA-256 für eine Datei (gechunkt für große Dateien).
    func sha256(for url: URL) throws -> String {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw HashError.fileNotFound
        }

        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        var hasher = SHA256()
        let chunkSize = 1024 * 1024 // 1 MB
        while let data = try handle.read(upToCount: chunkSize), !data.isEmpty {
            hasher.update(data: data)
        }
        return hasher.finalize().hexString
    }

    /// Vergleicht zwei Dateien über ihren Hash.
    func filesAreEqual(_ url1: URL, _ url2: URL) throws -> Bool {
        try sha256(for: url1) == sha256(for: url2)
    }
}

/// Hash-Fehler
enum HashError: Error {
    case fileNotFound
    case readError
}

// MARK: - Hilfs-Erweiterungen

extension Data {
    var sha256: String {
        SHA256.hash(data: self).hexString
    }
}

extension Sequence where Element == UInt8 {
    /// Hexadezimale Darstellung eines Byte-Streams (z. B. eines Hash-Digests).
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
