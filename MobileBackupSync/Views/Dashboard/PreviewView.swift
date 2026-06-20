//
//  PreviewView.swift
//  MobileBackupSync
//
//  Created on 2026-06-21.
//

import SwiftUI

struct PreviewView: View {
    @Environment(\.dismiss) var dismiss
    @State private var compareResult: CompareResult?
    @State private var isComparing = true
    
    var body: some View {
        NavigationStack {
            Group {
                if isComparing {
                    ProgressView("Vergleiche...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let result = compareResult {
                    CompareResultView(result: result)
                } else {
                    Text("Fehler beim Vergleich")
                        .foregroundColor(.red)
                }
            }
            .navigationTitle("Vorschau")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Schließen") {
                        dismiss()
                    }
                }
            }
            .task {
                await performCompare()
            }
        }
    }
    
    private func performCompare() async {
        // TODO: CompareEngine aufrufen
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        compareResult = CompareResult()
        isComparing = false
    }
}

/// Vergleichsergebnis-Ansicht
struct CompareResultView: View {
    let result: CompareResult
    @State private var selectedFilter: FileFilter = .all
    
    enum FileFilter: String, CaseIterable {
        case all = "Alle"
        case new = "Neu"
        case modified = "Geändert"
        case deleted = "Gelöscht"
        case unchanged = "Unverändert"
    }
    
    var filteredFiles: [FileItem] {
        switch selectedFilter {
        case .all: return result.newFiles + result.modifiedFiles + result.deletedFiles + result.unchangedFiles
        case .new: return result.newFiles
        case .modified: return result.modifiedFiles
        case .deleted: return result.deletedFiles
        case .unchanged: return result.unchangedFiles
        }
    }
    
    var body: some View {
        Form {
            // Zusammenfassung
            Section("Zusammenfassung") {
                HStack {
                    Text("Gesamt:")
                    Spacer()
                    Text("\(result.totalFiles)")
                }
                HStack {
                    Text("Neu:")
                    Spacer()
                    Text("\(result.newFiles.count)")
                        .foregroundColor(.green)
                }
                HStack {
                    Text("Geändert:")
                    Spacer()
                    Text("\(result.modifiedFiles.count)")
                        .foregroundColor(.orange)
                }
                HStack {
                    Text("Gelöscht:")
                    Spacer()
                    Text("\(result.deletedFiles.count)")
                        .foregroundColor(.red)
                }
                HStack {
                    Text("Zu übertragen:")
                    Spacer()
                    Text("\(result.filesToTransfer)")
                }
                HStack {
                    Text("Größe:")
                    Spacer()
                    Text(ByteCountFormatter.string(fromByteCount: result.bytesToTransfer, countStyle: .file))
                }
            }
            
            // Filter
            Section("Filter") {
                Picker("Filter", selection: $selectedFilter) {
                    ForEach(FileFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            // Dateiliste
            Section("Dateien") {
                ForEach(filteredFiles) { file in
                    FileRowView(file: file)
                }
            }
        }
    }
}

/// Einzelne Datei im Vergleich
struct FileRowView: View {
    let file: FileItem
    
    var statusColor: Color {
        switch file.syncStatus {
        case .new: return .green
        case .modified: return .orange
        case .deleted: return .red
        case .unchanged: return .secondary
        case .conflict: return .purple
        case .error: return .red
        }
    }
    
    var body: some View {
        HStack {
            Image(systemName: file.isDirectory ? "folder" : "doc")
                .foregroundColor(statusColor)
            
            VStack(alignment: .leading) {
                Text(file.name)
                    .font(.headline)
                Text(file.formattedSize)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(file.syncStatus.displayName)
                .font(.caption)
                .foregroundColor(statusColor)
        }
    }
}

#Preview {
    PreviewView()
}
