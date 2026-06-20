//
//  JobsView.swift
//  MobileBackupSync
//
//  Created on 2026-06-21.
//

import SwiftUI

struct JobsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingNewJob = false
    
    var body: some View {
        NavigationStack {
            Group {
                if appState.completedJobs.isEmpty {
                    ContentUnavailableView(
                        "Keine Jobs",
                        systemImage: "list.bullet",
                        description: Text("Erstelle einen neuen Backup-Job")
                    )
                } else {
                    List {
                        ForEach(appState.completedJobs) { job in
                            JobRowView(job: job)
                        }
                    }
                }
            }
            .navigationTitle("Jobs")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingNewJob = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewJob) {
                NewJobView()
            }
        }
    }
}

/// Job-Zeile
struct JobRowView: View {
    let job: SyncJob
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(job.name)
                .font(.headline)
            
            HStack {
                Text(job.mode.displayName)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(4)
                
                Spacer()
                
                if let lastRun = job.lastRunAt {
                    Text(lastRun, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

/// Neuer Job erstellen
struct NewJobView: View {
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var mode: SyncMode = .backup
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Job-Name", text: $name)
                }
                
                Section("Modus") {
                    Picker("Modus", selection: $mode) {
                        ForEach(SyncMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    Text(mode.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Neuer Job")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Erstellen") {
                        // TODO: Job speichern
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

#Preview {
    JobsView()
        .environmentObject(AppState())
}
