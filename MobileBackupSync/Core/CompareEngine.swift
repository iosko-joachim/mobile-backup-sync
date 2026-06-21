//
//  CompareEngine.swift
//  MobileBackupSync
//
//  Created on 2026-06-21.
//

import Foundation

/// Engine für den rekursiven Vergleich von Quelle und Ziel.
/// Dateien werden über ihren `relativePath` einander zugeordnet.
final class CompareEngine {

    /// Quelle und Ziel vergleichen.
    func compare(
        source: StorageLocation,
        destination: StorageLocation,
        options: SyncOptions
    ) async throws -> CompareResult {
        var result = CompareResult()

        let sourceProvider = source.makeProvider()
        let destProvider = destination.makeProvider()

        try await sourceProvider.connect()
        defer { Task { await sourceProvider.disconnect() } }
        try await destProvider.connect()
        defer { Task { await destProvider.disconnect() } }

        let sourceFiles = try await sourceProvider.listFiles()
        let destFiles = try await destProvider.listFiles()
        let destByPath = Dictionary(destFiles.map { ($0.relativePath, $0) }, uniquingKeysWith: { a, _ in a })
        let sourcePaths = Set(sourceFiles.map(\.relativePath))

        for sourceFile in sourceFiles {
            guard let destFile = destByPath[sourceFile.relativePath] else {
                var f = sourceFile; f.syncStatus = .new
                result.newFiles.append(f)
                continue
            }

            let status = try await compareFiles(
                sourceFile, destFile,
                options: options,
                sourceProvider: sourceProvider,
                destProvider: destProvider
            )
            var f = sourceFile; f.syncStatus = status
            switch status {
            case .modified: result.modifiedFiles.append(f)
            case .conflict: result.conflictFiles.append(f)
            default: result.unchangedFiles.append(f)
            }
        }

        // Nur am Ziel vorhandene Dateien gelten als "gelöscht" (relevant für Mirror).
        for destFile in destFiles where !sourcePaths.contains(destFile.relativePath) {
            var f = destFile; f.syncStatus = .deleted
            result.deletedFiles.append(f)
        }

        return result
    }

    /// Zwei Dateien vergleichen (Größe → Datum → optional Hash).
    private func compareFiles(
        _ source: FileItem,
        _ destination: FileItem,
        options: SyncOptions,
        sourceProvider: StorageProvider,
        destProvider: StorageProvider
    ) async throws -> FileSyncStatus {
        if source.size != destination.size {
            return .modified
        }

        let timeDiff = abs(source.modifiedDate.timeIntervalSince(destination.modifiedDate))

        if options.compareByHash {
            // Größe gleich – Inhalt per Hash absichern.
            let sourceHash = (try? await sourceProvider.readData(at: source.relativePath))?.sha256
            let destHash = (try? await destProvider.readData(at: destination.relativePath))?.sha256
            if let s = sourceHash, let d = destHash {
                return s == d ? .unchanged : .modified
            }
        }

        // 2 Sekunden Toleranz für Zeitstempel-Ungenauigkeiten (z. B. FAT/SMB).
        return timeDiff > 2 ? .modified : .unchanged
    }
}
