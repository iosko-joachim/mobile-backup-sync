//
//  SyncEngine.swift
//  MobileBackupSync
//
//  Created on 2026-06-21.
//

import Foundation
import Combine

/// Haupt-Engine für Sync- und Backup-Operationen
@MainActor
class SyncEngine: ObservableObject {
    /// Aktueller Fortschritt (0.0 - 1.0)
    @Published var progress: Double = 0.0
    
    /// Aktueller Status
    @Published var status: SyncStatus = .idle
    
    /// Aktuelle Datei im Transfer
    @Published var currentFile: String?
    
    /// Übertragene Bytes
    @Published var transferredBytes: Int64 = 0
    
    /// Gesamte Bytes
    @Published var totalBytes: Int64 = 0
    
    /// Fortschritts-Stream
    @Published var progressUpdates: [ProgressUpdate] = []
    
    /// Fehler-Stream
    @Published var errors: [SyncError] = []
    
    /// Abbruch-Signal
    private var isCancelled = false
    
    /// CompareEngine für den Vergleich
    private let compareEngine: CompareEngine
    
    /// TransferManager für Transfers
    private let transferManager: TransferManager
    
    /// ConflictResolver für Konflikte
    private let conflictResolver: ConflictResolver
    
    init(
        compareEngine: CompareEngine = CompareEngine(),
        transferManager: TransferManager = TransferManager(),
        conflictResolver: ConflictResolver = ConflictResolver()
    ) {
        self.compareEngine = compareEngine
        self.transferManager = transferManager
        self.conflictResolver = conflictResolver
    }
    
    /// Sync-Job ausführen
    func execute(job: SyncJob) async throws -> SyncResult {
        reset()
        
        guard !isCancelled else {
            return SyncResult(status: .cancelled, filesProcessed: 0)
        }
        
        do {
            // Phase 1: Vergleich
            status = .comparing
            let compareResult = try await compareEngine.compare(
                source: job.source,
                destination: job.destination,
                options: job.options
            )
            
            guard !isCancelled else {
                return SyncResult(status: .cancelled, filesProcessed: 0)
            }
            
            // Phase 2: Transfer vorbereiten
            status = .preparing
            let plannedFiles = planTransfer(compareResult: compareResult, mode: job.mode)
            
            guard !isCancelled else {
                return SyncResult(status: .cancelled, filesProcessed: 0)
            }
            
            // Dry Run?
            if job.options.dryRun {
                status = .done
                return SyncResult(
                    status: .done,
                    filesProcessed: 0,
                    plannedFiles: plannedFiles,
                    isDryRun: true
                )
            }
            
            // Phase 3: Transfer ausführen
            status = .transferring
            let result = try await transferManager.transfer(
                files: plannedFiles,
                source: job.source,
                destination: job.destination,
                options: job.options,
                onProgress: { [weak self] update in
                    Task { @MainActor in
                        self?.handleProgress(update: update)
                    }
                },
                onError: { [weak self] error in
                    Task { @MainActor in
                        self?.handleError(error)
                    }
                }
            )
            
            status = .done
            return result
            
        } catch let error as SyncError {
            status = .failed(error.localizedDescription)
            throw error
        } catch {
            let syncError = SyncError.unknown(error)
            status = .failed(syncError.localizedDescription)
            throw syncError
        }
    }
    
    /// Transfer planen basierend auf Vergleichsergebnis
    private func planTransfer(compareResult: CompareResult, mode: SyncMode) -> [PlannedFile] {
        var planned: [PlannedFile] = []
        
        switch mode {
        case .backup, .mirror:
            // Neue und geänderte Dateien von Quelle zu Ziel
            for file in compareResult.newFiles {
                planned.append(PlannedFile(file: file, action: .copy, resolution: .useSource))
            }
            for file in compareResult.modifiedFiles {
                planned.append(PlannedFile(file: file, action: .update, resolution: .useSource))
            }
            
            // Bei Mirror: Gelöschte auch am Ziel löschen
            if mode == .mirror {
                for file in compareResult.deletedFiles {
                    planned.append(PlannedFile(file: file, action: .delete, resolution: .useSource))
                }
            }
            
        case .bidirectional:
            // Bidirektional: Beide Richtungen
            for file in compareResult.newFiles {
                planned.append(PlannedFile(file: file, action: .copy, resolution: .useSource))
            }
            for file in compareResult.modifiedFiles {
                planned.append(PlannedFile(file: file, action: .update, resolution: .useSource))
            }
            for file in compareResult.conflictFiles {
                // Konflikte zur manuellen Auflösung markieren
                planned.append(PlannedFile(file: file, action: .conflict, resolution: .manual))
            }
        }
        
        return planned
    }
    
    /// Fortschritts-Update verarbeiten
    private func handleProgress(update: ProgressUpdate) {
        progress = update.progress
        currentFile = update.currentFile
        transferredBytes = update.transferredBytes
        totalBytes = update.totalBytes
        progressUpdates.append(update)
    }
    
    /// Fehler verarbeiten
    private func handleError(_ error: SyncError) {
        errors.append(error)
    }
    
    /// Zustand zurücksetzen
    private func reset() {
        progress = 0.0
        status = .idle
        currentFile = nil
        transferredBytes = 0
        totalBytes = 0
        progressUpdates = []
        errors = []
        isCancelled = false
    }
    
    /// Sync abbrechen
    func cancel() {
        isCancelled = true
        transferManager.cancel()
    }
}

/// Geplante Datei für Transfer
struct PlannedFile {
    let file: FileItem
    let action: FileAction
    let resolution: ConflictResolution
}

/// Datei-Aktion
enum FileAction {
    case copy      // Neue Datei kopieren
    case update    // Geänderte Datei aktualisieren
    case delete    // Datei löschen
    case conflict  // Konflikt zur Auflösung markieren
}

/// Fortschritts-Update
struct ProgressUpdate {
    let progress: Double
    let currentFile: String
    let transferredBytes: Int64
    let totalBytes: Int64
    let timestamp: Date
}

/// Sync-Ergebnis
struct SyncResult {
    let status: SyncStatus
    let filesProcessed: Int
    let plannedFiles: [PlannedFile]?
    let isDryRun: Bool
    let errors: [SyncError]
    let duration: TimeInterval
    
    init(
        status: SyncStatus,
        filesProcessed: Int = 0,
        plannedFiles: [PlannedFile]? = nil,
        isDryRun: Bool = false,
        errors: [SyncError] = [],
        duration: TimeInterval = 0
    ) {
        self.status = status
        self.filesProcessed = filesProcessed
        self.plannedFiles = plannedFiles
        self.isDryRun = isDryRun
        self.errors = errors
        self.duration = duration
    }
}

/// Sync-Fehler
enum SyncError: Error {
    case sourceNotFound
    case destinationNotFound
    case connectionFailed(String)
    case authenticationFailed
    case transferFailed(String)
    case insufficientSpace
    case cancelled
    case unknown(Error)
    
    var localizedDescription: String {
        switch self {
        case .sourceNotFound: return "Quelle nicht gefunden"
        case .destinationNotFound: return "Ziel nicht gefunden"
        case .connectionFailed(let msg): return "Verbindung fehlgeschlagen: \(msg)"
        case .authenticationFailed: return "Authentifizierung fehlgeschlagen"
        case .transferFailed(let msg): return "Transfer fehlgeschlagen: \(msg)"
        case .insufficientSpace: return "Nicht genügend Speicherplatz"
        case .cancelled: return "Vorgang abgebrochen"
        case .unknown(let error): return "Unbekannter Fehler: \(error.localizedDescription)"
        }
    }
}
