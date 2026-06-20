//
//  LogView.swift
//  MobileBackupSync
//
//  Created on 2026-06-21.
//

import SwiftUI

struct LogView: View {
    @State private var logEntries: [LogEntry] = []
    @State private var selectedLevel: LogLevel = .all
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter
                Picker("Level", selection: $selectedLevel) {
                    Text("Alle").tag(LogLevel.all)
                    Text("Fehler").tag(LogLevel.error)
                    Text("Warnung").tag(LogLevel.warning)
                    Text("Info").tag(LogLevel.info)
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Log-Einträge
                List {
                    ForEach(filteredEntries) { entry in
                        LogEntryRow(entry: entry)
                    }
                }
            }
            .navigationTitle("Protokoll")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Exportieren") {
                            // TODO: Log exportieren
                        }
                        Button("Löschen", role: .destructive) {
                            logEntries.removeAll()
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .onAppear {
            loadLogs()
        }
    }
    
    private var filteredEntries: [LogEntry] {
        if selectedLevel == .all {
            return logEntries
        }
        return logEntries.filter { $0.level == selectedLevel }
    }
    
    private func loadLogs() {
        // TODO: Logs aus LogService laden
        logEntries = [
            LogEntry(level: .info, message: "App gestartet", timestamp: Date()),
            LogEntry(level: .info, message: "Backup job erstellt", timestamp: Date().addingTimeInterval(-60)),
        ]
    }
}

/// Log-Eintrag
struct LogEntry: Identifiable {
    let id = UUID()
    let level: LogLevel
    let message: String
    let timestamp: Date
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: timestamp)
    }
}

/// Log-Level
enum LogLevel: String, CaseIterable {
    case all = "Alle"
    case error = "Fehler"
    case warning = "Warnung"
    case info = "Info"
    case debug = "Debug"
}

/// Log-Eintrag Zeile
struct LogEntryRow: View {
    let entry: LogEntry
    
    var levelColor: Color {
        switch entry.level {
        case .error: return .red
        case .warning: return .orange
        case .info: return .blue
        case .debug: return .gray
        case .all: return .secondary
        }
    }
    
    var levelIcon: String {
        switch entry.level {
        case .error: return "exclamationmark.triangle.fill"
        case .warning: return "exclamationmark.triangle"
        case .info: return "info.circle.fill"
        case .debug: return "bug.fill"
        case .all: return "list.bullet"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: levelIcon)
                    .foregroundColor(levelColor)
                Text(entry.formattedDate)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Text(entry.message)
                .font(.body)
        }
    }
}

#Preview {
    LogView()
}
