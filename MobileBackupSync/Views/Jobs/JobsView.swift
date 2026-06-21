//
//  JobsView.swift
//  MobileBackupSync
//
//  Created on 2026-06-21.
//

import SwiftUI

struct JobsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationStack {
            Group {
                if appState.completedJobs.isEmpty {
                    if #available(iOS 17.0, *) {
                        ContentUnavailableView(
                            "Keine Jobs",
                            systemImage: "list.bullet",
                            description: Text("Starte ein Backup im Tab „Backup“.")
                        )
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "list.bullet")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            Text("Keine Jobs")
                                .font(.headline)
                            Text("Starte ein Backup im Tab „Backup“.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    List {
                        ForEach(appState.completedJobs) { job in
                            JobRowView(job: job)
                        }
                    }
                }
            }
            .navigationTitle("Jobs")
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

#Preview {
    JobsView()
        .environmentObject(AppState())
}
