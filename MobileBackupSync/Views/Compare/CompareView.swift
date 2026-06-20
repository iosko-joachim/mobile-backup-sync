//
//  CompareView.swift
//  MobileBackupSync
//
//  Created on 2026-06-21.
//

import SwiftUI

struct CompareView: View {
    @State private var sourceURL: URL?
    @State private var destinationURL: URL?
    @State private var compareResult: CompareResult?
    @State private var isComparing = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Quelle") {
                    Button("Ordner auswählen") {
                        // TODO: DocumentPicker
                    }
                    if let url = sourceURL {
                        Text(url.path)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Ziel") {
                    Button("Ordner auswählen") {
                        // TODO: DocumentPicker
                    }
                    if let url = destinationURL {
                        Text(url.path)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section {
                    Button(action: startCompare) {
                        HStack {
                            Spacer()
                            Label("Vergleichen", systemImage: "doc.text.magnifyingglass")
                            Spacer()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(sourceURL == nil || destinationURL == nil)
                    .disabled(isComparing)
                }
                
                if isComparing {
                    Section {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                        Text("Vergleiche...")
                            .foregroundColor(.secondary)
                    }
                }
                
                if let result = compareResult {
                    Section("Ergebnis") {
                        CompareResultSummaryView(result: result)
                    }
                }
            }
            .navigationTitle("Vergleich")
        }
    }
    
    private func startCompare() {
        isComparing = true
        // TODO: CompareEngine aufrufen
    }
}

/// Zusammenfassung des Vergleichs
struct CompareResultSummaryView: View {
    let result: CompareResult
    
    var body: some View {
        VStack(spacing: 8) {
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
        }
        .font(.body)
    }
}

#Preview {
    CompareView()
}
