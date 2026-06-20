//
//  JobSummaryView.swift
//  MobileBackupSync
//
//  Created on 2026-06-21.
//

import SwiftUI

/// Zusammenfassung eines Jobs für das Dashboard
struct JobSummaryView: View {
    let job: SyncJob
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(job.name)
                    .font(.headline)
                Text(job.mode.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if let lastRun = job.lastRunAt {
                VStack(alignment: .trailing) {
                    Text("Zuletzt:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(lastRun, style: .date)
                        .font(.caption)
                }
            }
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
