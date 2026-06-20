//
//  ConflictResolver.swift
//  MobileBackupSync
//
//  Created on 2026-06-21.
//

import Foundation

/// Löst Sync-Konflikte auf
actor ConflictResolver {
    
    /// Konflikt automatisch auflösen (wenn Regel definiert)
    func resolveAutomatically(
        conflict: ConflictInfo,
        rule: ConflictResolutionRule
    ) -> ConflictResolution {
        switch rule {
        case .newerWins:
            return conflict.newerSide == .source ? .useSource : .useDestination
            
        case .largerWins:
            return conflict.largerSide == .source ? .useSource : .useDestination
            
        case .sourceWins:
            return .useSource
            
        case .destinationWins:
            return .useDestination
            
        case .keepBoth:
            return .keepBoth
            
        case .manual:
            return .manual
        }
    }
    
    /// Konflikt manuell auflösen
    func resolveManually(
        source: FileItem,
        destination: FileItem,
        userChoice: ConflictResolution
    ) -> ConflictResolution {
        userChoice
    }
}

/// Regel für automatische Konfliktauflösung
enum ConflictResolutionRule: Codable, CaseIterable {
    case newerWins
    case largerWins
    case sourceWins
    case destinationWins
    case keepBoth
    case manual
    
    var displayName: String {
        switch self {
        case .newerWins: return "Neuere Datei gewinnt"
        case .largerWins: return "Größere Datei gewinnt"
        case .sourceWins: return "Quelle gewinnt"
        case .destinationWins: return "Ziel gewinnt"
        case .keepBoth: return "Beide behalten"
        case .manual: return "Manuell entscheiden"
        }
    }
}
