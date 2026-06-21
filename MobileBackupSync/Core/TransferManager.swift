//
//  TransferManager.swift
//  MobileBackupSync
//
//  Created on 2026-06-21.
//

import Foundation

/// Manager für Datei-Transfers
class TransferManager {
    
    /// Abbruch-Signal
    private var isCancelled = false
    
    /// Maximale Retry-Versuche
    private let maxRetries = 3
    
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
        let startTime = Date()
        
        for (index, plannedFile) in files.enumerated() {
            guard !isCancelled else {
                return SyncResult(status: .cancelled, filesProcessed: filesProcessed)
            }
            
            // Skip delete actions for now (only for mirror mode)
            if plannedFile.action == .delete {
                filesProcessed += 1
                continue
            }
            
            do {
                // Retry-Logik
                var lastError: Error?
                for attempt in 1...maxRetries {
                    do {
                        try await transferFile(
                            plannedFile: plannedFile,
                            source: source,
                            destination: destination,
                            options: options,
                            onProgress: { [weak self] progress in
                                guard let self else { return }
                                let fileProgress = Double(index) / Double(files.count)
                                let currentFileProgress = progress / Double(files.count)
                                let totalProgress = fileProgress + currentFileProgress
                                
                                let bytes = Int64(Double(totalBytes) * totalProgress)
                                onProgress(ProgressUpdate(
                                    progress: totalProgress,
                                    currentFile: plannedFile.file.name,
                                    transferredBytes: bytes,
                                    totalBytes: totalBytes,
                                    timestamp: Date()
                                ))
                            }
                        )
                        filesProcessed += 1
                        break // Erfolg, keine weitere Retry
                    } catch let error {
                        lastError = error
                        if attempt < maxRetries {
                            // Kurze Pause vor Retry
                            try await Task.sleep(nanoseconds: 500_000_000)
                        }
                    }
                }
                
                if let error = lastError {
                    throw error
                }
                
            } catch let syncError as SyncError {
                errors.append(syncError)
                onError(syncError)
            } catch {
                let syncError = SyncError.transferFailed(error.localizedDescription)
                errors.append(syncError)
                onError(syncError)
            }
        }
        
        let duration = Date().timeIntervalSince(startTime)
        
        return SyncResult(
            status: errors.isEmpty ? .done : .failed("Einige Fehler aufgetreten"),
            filesProcessed: filesProcessed,
            errors: errors,
            duration: duration
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
        switch (source, destination) {
        case (.local(let sourceURL), .smb(let smbConfig)):
            // Lokal → SMB
            try await transferLocalToSMB(
                source: sourceURL,
                config: smbConfig,
                destinationPath: plannedFile.file.path,
                onProgress: onProgress
            )
            
        case (.smb(let smbConfig), .local(let destinationURL)):
            // SMB → Lokal (Restore)
            try await transferSMBToLocal(
                sourcePath: plannedFile.file.path,
                config: smbConfig,
                destination: destinationURL,
                onProgress: onProgress
            )
            
        default:
            // TODO: Andere Kombinationen
            throw SyncError.transferFailed("Nicht unterstützte Transfer-Kombination")
        }
    }
    
    /// Transfer: Lokal → SMB
    private func transferLocalToSMB(
        source: URL,
        config: SMBConfig,
        destinationPath: String,
        onProgress: @escaping (Double) -> Void
    ) async throws {
        let provider = SMBStorageProvider(config: config)
        try await provider.connect()
        
        // Datei lesen
        let data = try Data(contentsOf: source)
        
        // Auf SMB schreiben
        try await provider.writeFile(data: data, to: destinationPath, progress: onProgress)
        
        await provider.disconnect()
    }
    
    /// Transfer: SMB → Lokal
    private func transferSMBToLocal(
        sourcePath: String,
        config: SMBConfig,
        destination: URL,
        onProgress: @escaping (Double) -> Void
    ) async throws {
        let provider = SMBStorageProvider(config: config)
        try await provider.connect()
        
        // Von SMB lesen
        let data = try await provider.readFile(at: sourcePath)
        
        // Lokal schreiben
        try data.write(to: destination)
        onProgress(1.0)
        
        await provider.disconnect()
    }
    
    /// Transfer abbrechen
    func cancel() {
        isCancelled = true
    }
}
