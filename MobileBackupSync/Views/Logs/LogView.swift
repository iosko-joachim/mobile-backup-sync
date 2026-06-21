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
            Group {
                if filteredEntries.isEmpty {
                    Text("Keine Protokolleinträge")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filteredEntries) { entry in
                            LogEntryRow(entry: entry)
                        }
                    }
                }
            }
            .safeAreaInset(edge: .top) {
                Picker("Level", selection: $selectedLevel) {
                    Text("Alle").tag(LogLevel.all)
                    Text("Fehler").tag(LogLevel.error)
                    Text("Warnung").tag(LogLevel.warning)
                    Text("Info").tag(LogLevel.info)
                }
                .pickerStyle(.segmented)
                .padding()
                .background(.bar)
            }
            .navigationTitle("Protokoll")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        if let url = LogService.shared.export() {
                            ShareLink(item: url) {
                                Label("Exportieren", systemImage: "square.and.arrow.up")
                            }
                        }
                        Button("Aktualisieren", systemImage: "arrow.clockwise") {
                            loadLogs()
                        }
                        Button("Löschen", systemImage: "trash", role: .destructive) {
                            LogService.shared.clear()
                            loadLogs()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .onAppear(perform: loadLogs)
    }

    private var filteredEntries: [LogEntry] {
        if selectedLevel == .all {
            return logEntries
        }
        return logEntries.filter { $0.level == selectedLevel }
    }

    private func loadLogs() {
        // Neueste Einträge zuerst.
        logEntries = LogService.shared.getEntries().reversed()
    }
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
