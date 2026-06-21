//
//  LogService.swift
//  MobileBackupSync
//
//  Created on 2026-06-21.
//

import Foundation
import os.log

/// Service für strukturierte Protokollierung
class LogService {
    
    static let shared = LogService()
    
    private let logger: Logger
    private let fileLogger: FileLogger
    private var entries: [LogEntry] = []
    private let maxEntries = 1000
    
    init() {
        self.logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "de.jomative.mobilebackup", category: "App")
        self.fileLogger = FileLogger()
    }
    
    /// Log-Eintrag hinzufügen
    func log(_ message: String, level: LogLevel = .info) {
        let entry = LogEntry(level: level, message: message, timestamp: Date())
        entries.append(entry)
        
        // Alte Einträge entfernen
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
        
        // System Logger
        switch level {
        case .error: logger.error("\(message)")
        case .warning: logger.warning("\(message)")
        case .info: logger.info("\(message)")
        case .debug: logger.debug("\(message)")
        case .all: break
        }
        
        // File Logger
        Task {
            await fileLogger.write(entry)
        }
    }
    
    /// Alle Einträge holen
    func getEntries() -> [LogEntry] {
        entries
    }
    
    /// Einträge nach Level filtern
    func getEntries(level: LogLevel) -> [LogEntry] {
        if level == .all {
            return entries
        }
        return entries.filter { $0.level == level }
    }
    
    /// Logs löschen
    func clear() {
        entries.removeAll()
    }
    
    /// Logs exportieren
    func export() -> URL? {
        fileLogger.export()
    }
}

/// Logger für Datei-Ausgabe
private class FileLogger {
    
    private var fileURL: URL?
    
    init() {
        setupFileLogger()
    }
    
    private func setupFileLogger() {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        guard let documents = paths.first else { return }
        
        fileURL = documents.appendingPathComponent("NASBackup.log")
    }
    
    func write(_ entry: LogEntry) {
        guard let fileURL else { return }
        
        let line = "[\(entry.formattedDate)] [\(entry.level.rawValue.uppercased())] \(entry.message)\n"
        
        if let data = line.data(using: .utf8) {
            try? data.append(to: fileURL)
        }
    }
    
    func export() -> URL? {
        fileURL
    }
}

// MARK: - Data Extension für Append

extension Data {
    func append(to file: URL) throws {
        if let fileHandle = try? FileHandle(forWritingTo: file) {
            defer { try? fileHandle.close() }
            try fileHandle.seekToEnd()
            try fileHandle.write(contentsOf: self)
        } else {
            try write(to: file)
        }
    }
}
