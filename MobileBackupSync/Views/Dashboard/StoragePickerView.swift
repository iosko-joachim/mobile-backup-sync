//
//  StoragePickerView.swift
//  MobileBackupSync
//
//  Created on 2026-06-21.
//

import SwiftUI

/// Auswahl eines Speicherorts (lokaler Ordner oder SMB-Freigabe).
struct StoragePickerView: View {

    @Environment(\.dismiss) var dismiss
    @Binding var selection: StorageLocation?
    @State private var selectedType: StorageType = .local
    @State private var smbConfig = SMBConfig()
    @State private var localURL: URL?

    enum StorageType: String, CaseIterable {
        case local = "Lokal"
        case smb = "SMB"
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Typ", selection: $selectedType) {
                    ForEach(StorageType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)

                switch selectedType {
                case .local:
                    LocalStorageSection(url: $localURL, selection: $selection)
                case .smb:
                    SMBConfigSection(config: $smbConfig, selection: $selection)
                }
            }
            .navigationTitle("Speicherort")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Local Storage Section

struct LocalStorageSection: View {

    @Binding var url: URL?
    @Binding var selection: StorageLocation?

    var body: some View {
        Section("Lokaler Speicher") {
            DocumentPickerButton(
                label: "Ordner auswählen",
                onPick: { pickedURL in
                    url = pickedURL
                    selection = .local(pickedURL)
                }
            )

            if let url {
                HStack {
                    Image(systemName: "folder.fill")
                    Text(url.lastPathComponent)
                    Spacer()
                    Text("Ausgewählt")
                        .foregroundColor(.green)
                        .font(.caption)
                }
            }
        }
    }
}

// MARK: - SMB Config Section

struct SMBConfigSection: View {

    @Binding var config: SMBConfig
    @Binding var selection: StorageLocation?
    @State private var password = ""
    @State private var testingConnection = false
    @State private var testResult: Bool?

    var body: some View {
        Section("SMB-Server") {
            TextField("Name", text: $config.name)
            TextField("Host (IP oder Hostname)", text: $config.host)
                .keyboardType(.asciiCapable)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            TextField("Freigabe", text: $config.share)
            TextField("Pfad (optional)", text: $config.path)
            TextField("Benutzername", text: $config.username)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            SecureField("Passwort", text: $password)

            HStack {
                Button(action: testConnection) {
                    Label("Verbindung testen", systemImage: "checkmark.circle")
                }
                .disabled(config.host.isEmpty || config.share.isEmpty)

                if testingConnection {
                    ProgressView().scaleEffect(0.7)
                }
                if let testResult {
                    Image(systemName: testResult ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(testResult ? .green : .red)
                }
            }
        }

        Section {
            Button(action: save) {
                HStack { Spacer(); Text("Speichern"); Spacer() }
            }
            .disabled(config.host.isEmpty || config.share.isEmpty)
        }
    }

    /// Speichert das Passwort vor dem Test, damit der Provider es nutzen kann.
    private func persistPassword() {
        if !password.isEmpty {
            SettingsStore.shared.saveSMBPassword(
                host: config.host,
                username: config.username,
                password: password
            )
        }
    }

    private func testConnection() {
        persistPassword()
        testingConnection = true
        testResult = nil
        Task {
            let provider = SMBStorageProvider(config: config)
            let success = await provider.testConnection()
            await MainActor.run {
                testResult = success
                testingConnection = false
            }
        }
    }

    private func save() {
        persistPassword()
        selection = .smb(config)
    }
}
