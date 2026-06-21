//
//  SettingsView.swift
//  MobileBackupSync
//
//  Created on 2026-06-21.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("compareByHash") private var compareByHash = false
    @AppStorage("dryRun") private var dryRun = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Vergleich") {
                    Toggle("Nach Hash vergleichen", isOn: $compareByHash)
                    Text("Langsamer, aber genauer (SHA-256-Prüfung bei gleicher Größe).")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section("Probelauf") {
                    Toggle("Dry Run (nur Vorschau)", isOn: $dryRun)
                    Text("Vergleicht und plant, überträgt aber keine Dateien.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section("Über") {
                    LabeledContent("Version",
                                   value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–")
                    LabeledContent("Build",
                                   value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "–")
                }
            }
            .navigationTitle("Einstellungen")
        }
    }
}

#Preview {
    SettingsView()
}
