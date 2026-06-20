//
//  CompareEngine.swift
//  MobileBackupSync
//
//  Created on 2026-06-21.
//

import Foundation

/// Engine für den Vergleich von Quelle und Ziel
actor CompareEngine {
    
    /// Quelle und Ziel vergleichen
    func compare(
        source: StorageLocation,
        destination: StorageLocation,
        options: SyncOptions
    ) async throws -> CompareResult {
        // TODO: Implementierung
        // 1. Dateien auf Quelle auflisten
        // 2. Dateien auf Ziel auflisten
        // 3. Vergleichen nach Name, Größe, Datum, optional Hash
        // 4. CompareResult zurückgeben
        
        return CompareResult()
    }
    
    /// Zwei Dateien vergleichen
    private func compareFiles(
        _ source: FileItem,
        _ destination: FileItem?,
        options: SyncOptions
    ) -> FileSyncStatus {
        guard let destination else {
            return .new
        }
        
        // Nach Größe vergleichen
        if source.size != destination.size {
            return .modified
        }
        
        // Nach Datum vergleichen
        if source.modifiedDate != destination.modifiedDate {
            return .modified
        }
        
        // Optional: Nach Hash vergleichen
        if options.compareByHash {
            // TODO: Hash-Vergleich
        }
        
        return .unchanged
    }
    
    /// Hash für Datei berechnen
    private func calculateHash(for file: FileItem, provider: any StorageProvider) async throws -> String {
        // TODO: Hash-Berechnung implementieren
        return ""
    }
}
