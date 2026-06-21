//
//  CompareEngine.swift
//  MobileBackupSync
//
//  Created on 2026-06-21.
//

import Foundation

/// Engine für den Vergleich von Quelle und Ziel
class CompareEngine {
    
    /// Quelle und Ziel vergleichen
    func compare(
        source: StorageLocation,
        destination: StorageLocation,
        options: SyncOptions
    ) async throws -> CompareResult {
        var result = CompareResult()
        
        // 1. Dateien auf Quelle auflisten
        let sourceFiles = try await listFiles(at: source)
        
        // 2. Dateien auf Ziel auflisten
        let destinationFiles = try await listFiles(at: destination)
        
        // 3. Vergleichen
        for sourceFile in sourceFiles {
            if let destFile = destinationFiles.first(where: { $0.name == sourceFile.name }) {
                // Datei existiert auf beiden Seiten - vergleichen
                let status = compareFiles(sourceFile, destFile, options: options)
                
                switch status {
                case .unchanged:
                    result.unchangedFiles.append(sourceFile)
                case .modified:
                    result.modifiedFiles.append(sourceFile)
                case .conflict:
                    result.conflictFiles.append(sourceFile)
                default:
                    break
                }
            } else {
                // Datei nur auf Quelle - neu
                result.newFiles.append(sourceFile)
            }
        }
        
        // 4. Gelöschte Dateien finden (nur auf Ziel)
        for destFile in destinationFiles {
            if !sourceFiles.contains(where: { $0.name == destFile.name }) {
                result.deletedFiles.append(destFile)
            }
        }
        
        return result
    }
    
    /// Dateien an einem Speicherort auflisten
    private func listFiles(at location: StorageLocation) async throws -> [FileItem] {
        switch location {
        case .local(let url):
            let provider = LocalStorageProvider()
            try await provider.connect()
            return try await provider.listContents(at: url.path)
            
        case .smb(let config):
            let provider = SMBStorageProvider(config: config)
            try await provider.connect()
            return try await provider.listContents(at: "/" + config.share + "/" + config.path)
            
        case .ssh, .webdav, .cloud:
            // TODO: Implementierung für andere Provider
            return []
        }
    }
    
    /// Zwei Dateien vergleichen
    private func compareFiles(
        _ source: FileItem,
        _ destination: FileItem,
        options: SyncOptions
    ) -> FileSyncStatus {
        // Nach Größe vergleichen (schnell)
        if source.size != destination.size {
            return .modified
        }
        
        // Nach Datum vergleichen
        let timeDiff = abs(source.modifiedDate.timeIntervalSince(destination.modifiedDate))
        if timeDiff > 2 { // 2 Sekunden Toleranz
            return .modified
        }
        
        // Optional: Nach Hash vergleichen (genau, aber langsam)
        if options.compareByHash {
            // TODO: Hash-Vergleich implementieren
        }
        
        return .unchanged
    }
}
