//
//  AppState.swift
//  MobileBackupSync
//
//  Created on 2026-06-21.
//

import Foundation
import Combine
import UIKit

/// Zentrale Anwendungsverwaltung. Spiegelt den Fortschritt der `SyncEngine`
/// in die UI und verwaltet Auswahl sowie Job-Historie.
@MainActor
class AppState: ObservableObject {
    /// Aktuell ausgewählte Quelle (über Neustarts persistiert)
    @Published var selectedSource: StorageLocation? {
        didSet { LocationStore.shared.save(selectedSource, for: .source) }
    }

    /// Aktuell ausgewähltes Ziel (über Neustarts persistiert)
    @Published var selectedDestination: StorageLocation? {
        didSet { LocationStore.shared.save(selectedDestination, for: .destination) }
    }

    /// Laufender Sync-Job
    @Published var currentJob: SyncJob?

    /// Abgeschlossene Jobs (Historie, neueste zuerst)
    @Published var completedJobs: [SyncJob] = []

    /// Gesamter Fortschritt (0.0 - 1.0)
    @Published var overallProgress: Double = 0.0

    /// Aktuelle Datei im Transfer
    @Published var currentFile: String?

    /// Aktueller Status
    @Published var status: SyncStatus = .idle

    /// Fehlermeldung
    @Published var errorMessage: String?

    /// Ergebnis des zuletzt gelaufenen Jobs
    @Published var lastResult: SyncResult?

    /// Engine, die die eigentliche Arbeit erledigt
    let syncEngine = SyncEngine()

    private var runTask: Task<Void, Never>?

    /// Initialisierung
    init() {
        // Persistierte Auswahl wiederherstellen. Direkte Zuweisung im init löst
        // `didSet` nicht aus, speichert also nicht unnötig zurück.
        selectedSource = LocationStore.shared.load(.source)
        selectedDestination = LocationStore.shared.load(.destination)
        bindEngine()
    }

    /// Spiegelt die Fortschritts-Publisher der Engine in die App-Zustände.
    private func bindEngine() {
        syncEngine.$progress.assign(to: &$overallProgress)
        syncEngine.$status.assign(to: &$status)
        syncEngine.$currentFile.assign(to: &$currentFile)
    }

    /// Ob aktuell ein Sync läuft
    var isRunning: Bool { runTask != nil }

    /// Sync starten
    func startSync(job: SyncJob) {
        guard runTask == nil else { return }
        currentJob = job
        errorMessage = nil
        lastResult = nil

        LogService.shared.log("Backup gestartet: \(job.name)", level: .info)

        // Bildschirm während des Transfers wach halten — sperrt sich das Display,
        // suspendiert iOS die App und der Lauf bricht ab.
        UIApplication.shared.isIdleTimerDisabled = true

        runTask = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await self.syncEngine.execute(job: job)
                var finished = job
                finished.lastRunAt = Date()
                self.completedJobs.insert(finished, at: 0)
                self.lastResult = result
                let suffix = result.isDryRun ? " (Probelauf)" : ""
                LogService.shared.log(
                    "Backup abgeschlossen\(suffix): \(result.filesProcessed) Datei(en), \(result.errors.count) Fehler",
                    level: result.errors.isEmpty ? .info : .warning
                )
            } catch {
                let message = (error as? SyncError)?.localizedDescription
                    ?? error.localizedDescription
                self.errorMessage = message
                LogService.shared.log("Backup fehlgeschlagen: \(message)", level: .error)
            }
            UIApplication.shared.isIdleTimerDisabled = false
            self.currentJob = nil
            self.runTask = nil
        }
    }

    /// Sync abbrechen
    func cancelSync() {
        syncEngine.cancel()
    }

    /// Status zurücksetzen (nur wenn kein Job läuft)
    func reset() {
        guard runTask == nil else { return }
        status = .idle
        currentJob = nil
        overallProgress = 0.0
        currentFile = nil
        errorMessage = nil
        lastResult = nil
    }
}

/// Mögliche Sync-Status
enum SyncStatus: Equatable {
    case idle
    case preparing
    case comparing
    case transferring
    case done
    case cancelled
    case failed(String)
}

/// Speicherort (Quelle oder Ziel)
enum StorageLocation: Identifiable, Equatable {
    case local(URL)
    case smb(SMBConfig)
    case ftp(FTPConfig)

    var id: String {
        switch self {
        case .local(let url): return url.absoluteString
        case .smb(let config): return config.id
        case .ftp(let config): return config.id
        }
    }

    var displayName: String {
        switch self {
        case .local(let url): return url.lastPathComponent
        case .smb(let config): return config.name.isEmpty ? config.host : config.name
        case .ftp(let config): return config.name.isEmpty ? config.host : config.name
        }
    }
}
