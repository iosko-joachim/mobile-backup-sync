//
//  FileItem.swift
//  MobileBackupSync
//
//  Created on 2026-06-21.
//

import Foundation

/// Repräsentiert eine Datei oder einen Ordner im Sync-Kontext
struct FileItem: Identifiable, Equatable {
    let id: UUID
    let name: String
    /// Vollständiger Pfad am Speicherort (zum Lesen/Schreiben).
    let path: String
    /// Pfad relativ zur Sync-Wurzel – Schlüssel für Vergleich und Zielpfad-Bildung.
    let relativePath: String
    let isDirectory: Bool
    let size: Int64
    let modifiedDate: Date
    let hash: String?

    /// Sync-Status dieser Datei
    var syncStatus: FileSyncStatus = .unchanged

    /// Konflikt-Information (falls zutreffend)
    var conflict: ConflictInfo?

    init(
        id: UUID = UUID(),
        name: String,
        path: String,
        relativePath: String? = nil,
        isDirectory: Bool,
        size: Int64,
        modifiedDate: Date,
        hash: String? = nil
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.relativePath = relativePath ?? name
        self.isDirectory = isDirectory
        self.size = size
        self.modifiedDate = modifiedDate
        self.hash = hash
    }
    
    /// Formatierter Größen-String
    var formattedSize: String {
        if isDirectory { return "-" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
    
    /// Formatierter Datums-String
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: modifiedDate)
    }
}

/// Sync-Status einer Datei
enum FileSyncStatus: Equatable {
    /// Unverändert
    case unchanged
    
    /// Neu (existiert nur auf einer Seite)
    case new
    
    /// Geändert
    case modified
    
    /// Gelöscht (existiert nicht mehr auf einer Seite)
    case deleted
    
    /// Konflikt (beide Seiten geändert)
    case conflict
    
    /// Fehler beim Vergleich/Transfer
    case error(String)
    
    var displayName: String {
        switch self {
        case .unchanged: return "Unverändert"
        case .new: return "Neu"
        case .modified: return "Geändert"
        case .deleted: return "Gelöscht"
        case .conflict: return "Konflikt"
        case .error: return "Fehler"
        }
    }
}

/// Konflikt-Information
struct ConflictInfo: Equatable {
    let sourceModified: Date
    let destinationModified: Date
    let sourceSize: Int64
    let destinationSize: Int64
    
    /// Welche Seite ist neuer?
    var newerSide: ConflictSide {
        if sourceModified > destinationModified {
            return .source
        } else if destinationModified > sourceModified {
            return .destination
        } else {
            return .bothSameTime
        }
    }
    
    /// Welche Seite ist größer?
    var largerSide: ConflictSide {
        if sourceSize > destinationSize {
            return .source
        } else if destinationSize > sourceSize {
            return .destination
        } else {
            return .bothSameSize
        }
    }
}

/// Konfliktauflösung
enum ConflictResolution: Codable {
    /// Quelle gewinnt
    case useSource
    
    /// Ziel gewinnt
    case useDestination
    
    /// Beide behalten (Umbenennung)
    case keepBoth
    
    /// Manuelle Entscheidung (später)
    case manual
    
    /// Überspringen
    case skip
}

/// Konfliktsseite
enum ConflictSide: Equatable {
    case source
    case destination
    case bothSameTime
    case bothSameSize
}

/// Ergebnis eines Vergleichs
struct CompareResult {
    /// Dateien die neu sind
    var newFiles: [FileItem] = []
    
    /// Dateien die geändert sind
    var modifiedFiles: [FileItem] = []
    
    /// Dateien die gelöscht wurden
    var deletedFiles: [FileItem] = []
    
    /// Unveränderte Dateien
    var unchangedFiles: [FileItem] = []
    
    /// Dateien mit Konflikten
    var conflictFiles: [FileItem] = []
    
    /// Gesamtanzahl
    var totalFiles: Int {
        newFiles.count + modifiedFiles.count + deletedFiles.count + unchangedFiles.count + conflictFiles.count
    }
    
    /// Anzahl der zu übertragenden Dateien
    var filesToTransfer: Int {
        newFiles.count + modifiedFiles.count
    }
    
    /// Gesamte zu übertragende Größe
    var bytesToTransfer: Int64 {
        newFiles.reduce(0) { $0 + $1.size } +
        modifiedFiles.reduce(0) { $0 + $1.size }
    }
}
