//
//  StorageProvider.swift
//  MobileBackupSync
//
//  Created on 2026-06-21.
//

import Foundation

/// Protokoll für alle Storage-Provider.
///
/// Jeder Provider kennt seine eigene Wurzel (lokaler Ordner bzw. Pfad in der
/// SMB-Freigabe). Alle Pfade in den Methoden sind **relativ** zu dieser Wurzel.
/// Das hält den `TransferManager` provider-agnostisch.
protocol StorageProvider: AnyObject {
    /// Verbindung herstellen (und ggf. Berechtigungen anfordern)
    func connect() async throws

    /// Verbindung trennen
    func disconnect() async

    /// Listet rekursiv alle **Dateien** unterhalb der Wurzel.
    /// `relativePath` der zurückgegebenen Items ist relativ zur Wurzel.
    func listFiles() async throws -> [FileItem]

    /// Liest eine Datei vollständig in den Speicher (v. a. für Hashing).
    func readData(at relativePath: String) async throws -> Data

    /// Lädt eine lokale Datei nach `relativePath` (legt Zielverzeichnisse an).
    func upload(from localURL: URL, to relativePath: String,
                progress: @escaping (Double) -> Void) async throws

    /// Schreibt die Datei an `relativePath` in eine lokale Datei.
    func download(at relativePath: String, to localURL: URL,
                  progress: @escaping (Double) -> Void) async throws

    /// Löscht eine Datei.
    func delete(at relativePath: String) async throws

    /// Setzt den Änderungszeitstempel einer Datei (relativ zur Wurzel).
    ///
    /// Wichtig für den inkrementellen Abgleich: Wird der Zeitstempel am Ziel
    /// nicht auf den der Quelle gesetzt, erscheinen beim nächsten Lauf alle
    /// Dateien als „geändert" und werden erneut kopiert.
    func setModificationDate(_ date: Date, at relativePath: String) async

    /// Freier Speicherplatz in Bytes (oder `Int64.max`, wenn unbekannt).
    func getFreeSpace() async throws -> Int64

    /// Verbindungstest
    func testConnection() async -> Bool
}

extension StorageProvider {
    /// Standard: keine Operation (Provider ohne setzbaren Zeitstempel).
    func setModificationDate(_ date: Date, at relativePath: String) async {}
}

/// Fehler des Storage-Providers
enum StorageProviderError: Error, LocalizedError {
    case notConnected
    case notFound(String)
    case permissionDenied(String)
    case networkError(String)
    case timeout
    case unsupported(String)
    case other(String)

    var errorDescription: String? {
        switch self {
        case .notConnected: return "Nicht verbunden"
        case .notFound(let p): return "Nicht gefunden: \(p)"
        case .permissionDenied(let p): return "Zugriff verweigert: \(p)"
        case .networkError(let m): return "Netzwerkfehler: \(m)"
        case .timeout: return "Zeitüberschreitung"
        case .unsupported(let m): return "Nicht unterstützt: \(m)"
        case .other(let m): return m
        }
    }
}

// MARK: - Provider-Erzeugung aus einem Speicherort

extension StorageLocation {
    /// Erzeugt den passenden Provider für diesen Speicherort.
    func makeProvider() -> StorageProvider {
        switch self {
        case .local(let url):
            return LocalStorageProvider(root: url)
        case .smb(let config):
            return SMBStorageProvider(config: config)
        case .ftp(let config):
            return FTPStorageProvider(config: config)
        }
    }
}
