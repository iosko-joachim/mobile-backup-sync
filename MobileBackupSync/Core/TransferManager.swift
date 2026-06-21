//
//  TransferManager.swift
//  MobileBackupSync
//
//  Created on 2026-06-21.
//

import Foundation

/// Manager für Datei-Transfers
actor TransferManager {
    
    /// Abbruch-Signal
    private var isCancelled = false
    
    /// Transfers ausführen
    func transfer(
        files: [PlannedFile],
        source: StorageLocation,
        destination: StorageLocation,
        options: SyncOptions,
        onProgress: @escaping (ProgressUpdate) -> Void,
        onError: @escaping (SyncError) -> Void
    ) async throws -> SyncResult {
        isCancelled = false
        
        var transferredBytes: Int64 = 0
        let totalBytes = files.reduce(0) { $0 + $1.file.size }
        var errors: [SyncError] = []
        var filesProcessed = 0
        
        for plannedFile in files {
            guard !isCancelled else {
                return SyncResult(status: .cancelled, filesProcessed: filesProcessed)
            }
            
            do {
                try await transferFile(
                    plannedFile: plannedFile,
                    source: source,
                    destination: destination,
                    options: options,
                    onProgress: { progress in
                        let bytes = Int64(Double(totalBytes) * progress)
                        onProgress(ProgressUpdate(
                            progress: progress,
                            currentFile: plannedFile.file.name,
                            transferredBytes: bytes,
                            totalBytes: totalBytes,
                            timestamp: Date()
                        ))
                    }
                )
                filesProcessed += 1
            } catch let error as SyncError {
                errors.append(error)
                onError(error)
            }
        }
        
        return SyncResult(
            status: errors.isEmpty ? .done : .failed("Einige Fehler aufgetreten"),
            filesProcessed: filesProcessed,
            errors: errors
        )
    }
    
    /// Einzelne Datei übertragen
    private func transferFile(
        plannedFile: PlannedFile,
        source: StorageLocation,
        destination: StorageLocation,
        options: SyncOptions,
        onProgress: @escaping (Double) -> Void
    ) async throws {
        // TODO: Implementierung
        // - Datei lesen
        // - Datei schreiben
        // - Fortschritt melden
        // - Retry-Logik
    }
    
    /// Transfer abbrechen
    func cancel() {
        isCancelled = true
    }
}
