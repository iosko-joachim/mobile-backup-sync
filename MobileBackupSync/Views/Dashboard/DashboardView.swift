//
//  DashboardView.swift
//  MobileBackupSync
//
//  Created on 2026-06-21.
//

import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingSourcePicker = false
    @State private var showingDestinationPicker = false
    @State private var showingPreview = false
    
    var body: some View {
        NavigationStack {
            Form {
                // Quelle
                Section("Quelle") {
                    Button(action: { showingSourcePicker = true }) {
                        HStack {
                            Image(systemName: "folder")
                            if let source = appState.selectedSource {
                                Text(source.displayName)
                            } else {
                                Text("Auswählen")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                // Ziel
                Section("Ziel") {
                    Button(action: { showingDestinationPicker = true }) {
                        HStack {
                            Image(systemName: "externaldrive")
                            if let destination = appState.selectedDestination {
                                Text(destination.displayName)
                            } else {
                                Text("Auswählen")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                // Vorschau
                Section {
                    Button(action: { showingPreview = true }) {
                        HStack {
                            Image(systemName: "doc.text.magnifyingglass")
                            Text("Vorschau anzeigen")
                        }
                    }
                    .disabled(appState.selectedSource == nil || appState.selectedDestination == nil)
                }
                
                // Start
                Section {
                    Button(action: startBackup) {
                        HStack {
                            Spacer()
                            Label("Backup starten", systemImage: "arrow.right.circle")
                                .font(.headline)
                            Spacer()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(appState.selectedSource == nil || appState.selectedDestination == nil)
                }
                
                // Status
                if appState.status != .idle {
                    Section("Status") {
                        StatusView()
                    }
                }
                
                // Letzte Jobs
                    Section("Letzte Jobs") {
                        if appState.completedJobs.isEmpty {
                            Text("Keine abgeschlossenen Jobs")
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(appState.completedJobs.prefix(3)) { job in
                                JobSummaryView(job: job)
                            }
                        }
                    }
            }
            .navigationTitle("Backup")
            .sheet(isPresented: $showingSourcePicker) {
                StoragePickerView(selection: $appState.selectedSource)
            }
            .sheet(isPresented: $showingDestinationPicker) {
                StoragePickerView(selection: $appState.selectedDestination)
            }
            .sheet(isPresented: $showingPreview) {
                PreviewView()
            }
        }
    }
    
    private func startBackup() {
        guard let source = appState.selectedSource,
              let destination = appState.selectedDestination else { return }
        
        let job = SyncJob(
            name: "Backup \(Date())",
            source: source,
            destination: destination,
            mode: .backup
        )
        
        appState.startSync(job: job)
    }
}

/// Status-Anzeige während Sync
struct StatusView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 12) {
            ProgressView(value: appState.overallProgress)
                .progressViewStyle(.linear)
            
            HStack {
                Text(appState.status.displayName)
                Spacer()
                Text("\(Int(appState.overallProgress * 100))%")
            }
            .font(.caption)
            
            if let currentFile = appState.currentFile {
                Text(currentFile)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            if appState.status == .transferring {
                Button("Abbrechen", role: .destructive) {
                    Task {
                        appState.cancelSync()
                    }
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 8)
    }
}

extension SyncStatus {
    var displayName: String {
        switch self {
        case .idle: return "Bereit"
        case .preparing: return "Vorbereiten..."
        case .comparing: return "Vergleichen..."
        case .transferring: return "Übertragen..."
        case .done: return "Abgeschlossen"
        case .cancelled: return "Abgebrochen"
        case .failed: return "Fehlgeschlagen"
        }
    }
}

#Preview {
    DashboardView()
        .environmentObject(AppState())
}
