//
//  SyncJob.swift
//  MobileBackupSync
//
//  Created on 2026-06-21.
//

import Foundation

/// Repräsentiert einen Sync-/Backup-Job
struct SyncJob: Identifiable {
    let id: UUID
    let name: String
    let source: StorageLocation
    let destination: StorageLocation
    let mode: SyncMode
    let options: SyncOptions
    let createdAt: Date
    var lastRunAt: Date?
    
    init(
        id: UUID = UUID(),
        name: String,
        source: StorageLocation,
        destination: StorageLocation,
        mode: SyncMode = .backup,
        options: SyncOptions = SyncOptions()
    ) {
        self.id = id
        self.name = name
        self.source = source
        self.destination = destination
        self.mode = mode
        self.options = options
        self.createdAt = Date()
    }
}

/// Sync-Modus
enum SyncMode: CaseIterable {
    /// Einweg-Backup (Quelle → Ziel)
    case backup
    
    /// Bidirektionale Synchronisation
    case bidirectional
    
    /// Spiegelung (Quelle → Ziel, löscht Extras am Ziel)
    case mirror
    
    var displayName: String {
        switch self {
        case .backup: return "Backup"
        case .bidirectional: return "Synchronisation"
        case .mirror: return "Spiegelung"
        }
    }
    
    var description: String {
        switch self {
        case .backup:
            return "Kopiert neue und geänderte Dateien vom Quell- zum Zielort."
        case .bidirectional:
            return "Synchronisiert Änderungen in beide Richtungen."
        case .mirror:
            return "Exakte Kopie des Quellorts (löscht Extras am Ziel)."
        }
    }
}

/// Sync-Optionen
struct SyncOptions {
    /// Vergleich nach Hash (langsamer, aber genauer)
    var compareByHash: Bool = false
    
    /// Nur im WLAN synchronisieren
    var wifiOnly: Bool = true
    
    /// Nur beim Laden synchronisieren
    var powerOnly: Bool = false
    
    /// Verschlüsselung aktivieren
    var encryptFiles: Bool = false
    
    /// Kompression aktivieren
    var compressFiles: Bool = false
    
    /// Dry Run (Vorschau ohne Ausführung)
    var dryRun: Bool = false
    
    /// Fortsetzen unterbrochener Transfers
    var resumeTransfers: Bool = true
    
    /// Maximale gleichzeitige Transfers
    var maxParallelTransfers: Int = 4
    
    /// Bandbreitenbegrenzung (KB/s, 0 = unbegrenzt)
    var bandwidthLimit: Int = 0
}
