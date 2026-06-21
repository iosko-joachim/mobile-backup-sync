//
//  AppState.swift
//  MobileBackupSync
//
//  Created on 2026-06-21.
//

import Foundation
import Combine

/// Zentrale Anwendungsverwaltung
@MainActor
class AppState: ObservableObject {
    /// Aktuell ausgewählte Quelle
    @Published var selectedSource: StorageLocation?
    
    /// Aktuell ausgewähltes Ziel
    @Published var selectedDestination: StorageLocation?
    
    /// Laufender Sync-Job
    @Published var currentJob: SyncJob?
    
    /// Abgeschlossene Jobs (Historie)
    @Published var completedJobs: [SyncJob] = []
    
    /// Gesamter Fortschritt (0.0 - 1.0)
    @Published var overallProgress: Double = 0.0
    
    /// Aktuelle Datei im Transfer
    @Published var currentFile: String?
    
    /// Aktueller Status
    @Published var status: SyncStatus = .idle
    
    /// Fehlermeldung
    @Published var errorMessage: String?
    
    /// Initialisierung
    init() {
        loadSavedSettings()
    }
    
    /// Gespeicherte Einstellungen laden
    private func loadSavedSettings() {
        // TODO: Aus SettingsStore laden
    }
    
    /// Sync starten
    func startSync(job: SyncJob) {
        currentJob = job
        status = .preparing
        // TODO: SyncEngine aufrufen
    }
    
    /// Sync abbrechen
    func cancelSync() async {
        status = .cancelled
        currentJob = nil
    }
    
    /// Status zurücksetzen
    func reset() {
        status = .idle
        currentJob = nil
        overallProgress = 0.0
        errorMessage = nil
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
    case ssh(SSHConfig)
    case webdav(WebDAVConfig)
    case cloud(CloudConfig)
    
    var id: String {
        switch self {
        case .local(let url): return url.absoluteString
        case .smb(let config): return config.id
        case .ssh(let config): return config.id
        case .webdav(let config): return config.id
        case .cloud(let config): return config.id
        }
    }
    
    var displayName: String {
        switch self {
        case .local(let url): return url.lastPathComponent
        case .smb(let config): return config.name
        case .ssh(let config): return config.name
        case .webdav(let config): return config.name
        case .cloud(let config): return config.name
        }
    }
}
