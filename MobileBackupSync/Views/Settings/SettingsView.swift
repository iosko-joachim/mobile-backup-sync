//
//  SettingsView.swift
//  MobileBackupSync
//
//  Created on 2026-06-21.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("wifiOnly") private var wifiOnly = true
    @AppStorage("powerOnly") private var powerOnly = false
    @AppStorage("compareByHash") private var compareByHash = false
    @AppStorage("encryptFiles") private var encryptFiles = false
    @AppStorage("dryRun") private var dryRun = false
    @AppStorage("maxParallelTransfers") private var maxParallelTransfers = 4
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Automatisierung") {
                    Toggle("Nur im WLAN", isOn: $wifiOnly)
                    Toggle("Nur beim Laden", isOn: $powerOnly)
                }
                
                Section("Vergleich") {
                    Toggle("Nach Hash vergleichen", isOn: $compareByHash)
                        .disabled(true) // TODO: Implementierung
                    Text("Langsamer, aber genauer")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("Sicherheit") {
                    Toggle("Dateien verschlüsseln", isOn: $encryptFiles)
                        .disabled(true) // TODO: Implementierung
                }
                
                Section("Performance") {
                    Stepper("Max. parallele Transfers: \(maxParallelTransfers)", value: $maxParallelTransfers, in: 1...8)
                }
                
                Section("Debug") {
                    Toggle("Dry Run (Vorschau)", isOn: $dryRun)
                    Text("Keine echten Änderungen")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("Über") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unbekannt")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Build")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unbekannt")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section {
                    Button("Logs anzeigen") {
                        // TODO: Zu Logs navigieren
                    }
                    
                    Button("Support kontaktieren") {
                        // TODO: Support-URL öffnen
                    }
                }
            }
            .navigationTitle("Einstellungen")
        }
    }
}

#Preview {
    SettingsView()
}
