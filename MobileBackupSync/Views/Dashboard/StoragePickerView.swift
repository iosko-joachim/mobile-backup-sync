//
//  StoragePickerView.swift
//  MobileBackupSync
//
//  Created on 2026-06-21.
//

import SwiftUI
import UniformTypeIdentifiers

struct StoragePickerView: View {
    
    @Environment(\.dismiss) var dismiss
    @Binding var selection: StorageLocation?
    @State private var selectedType: StorageType = .local
    @State private var smbConfig = SMBConfig()
    @State private var sshConfig = SSHConfig()
    @State private var webdavConfig = WebDAVConfig()
    @State private var cloudConfig = CloudConfig()
    @State private var localURL: URL?
    
    enum StorageType: String, CaseIterable {
        case local = "Lokal"
        case smb = "SMB"
        case ssh = "SSH/SFTP"
        case webdav = "WebDAV"
        case cloud = "Cloud"
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Picker("Typ", selection: $selectedType) {
                    ForEach(StorageType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                
                switch selectedType {
                case .local:
                    LocalStorageSection(url: $localURL, selection: $selection)
                case .smb:
                    SMBConfigSection(config: $smbConfig, selection: $selection)
                case .ssh:
                    SSHConfigSection(config: $sshConfig, selection: $selection)
                case .webdav:
                    WebDAVConfigSection(config: $webdavConfig, selection: $selection)
                case .cloud:
                    CloudConfigSection(config: $cloudConfig, selection: $selection)
                }
            }
            .navigationTitle("Speicherort")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") {
                        dismiss()
                    }
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
            
            if let url = url {
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
            TextField("Freigabe", text: $config.share)
            TextField("Pfad (optional)", text: $config.path)
            TextField("Benutzername", text: $config.username)
            SecureField("Passwort", text: $password)
            
            HStack {
                Button(action: testConnection) {
                    Label("Verbindung testen", systemImage: "checkmark.circle")
                }
                .disabled(config.host.isEmpty)
                
                if testingConnection {
                    ProgressView()
                        .scaleEffect(0.5)
                }
                
                if let result = testResult {
                    Image(systemName: result ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(result ? .green : .red)
                }
            }
        }
        
        Section {
            Button(action: save) {
                HStack {
                    Spacer()
                    Text("Speichern")
                    Spacer()
                }
            }
            .disabled(config.host.isEmpty || config.share.isEmpty)
        }
    }
    
    private func testConnection() {
        testingConnection = true
        Task {
            let provider = SMBStorageProvider(config: config)
            let success = await provider.testConnection()
            testResult = success
            testingConnection = false
        }
    }
    
    private func save() {
        // Passwort im Keychain speichern
        if !password.isEmpty {
            SettingsStore.shared.saveSMBPassword(
                host: config.host,
                username: config.username,
                password: password
            )
        }
        selection = .smb(config)
    }
}

// MARK: - SSH Config Section

struct SSHConfigSection: View {
    
    @Binding var config: SSHConfig
    @Binding var selection: StorageLocation?
    @State private var password = ""
    
    var body: some View {
        Section("SSH/SFTP-Server") {
            TextField("Name", text: $config.name)
            TextField("Host", text: $config.host)
                .keyboardType(.asciiCapable)
            TextField("Pfad", text: $config.path)
            TextField("Benutzername", text: $config.username)
            SecureField("Passwort", text: $password)
            
            Picker("Authentifizierung", selection: $config.authMethod) {
                Text("Passwort").tag(SSHAuthMethod.password)
                Text("SSH-Key").tag(SSHAuthMethod.key("default"))
            }
        }
        
        Section {
            Button(action: save) {
                HStack {
                    Spacer()
                    Text("Speichern")
                    Spacer()
                }
            }
            .disabled(config.host.isEmpty)
        }
    }
    
    private func save() {
        if !password.isEmpty {
            SettingsStore.shared.saveSMBPassword(
                host: config.host,
                username: config.username,
                password: password
            )
        }
        selection = .ssh(config)
    }
}

// MARK: - WebDAV Config Section

struct WebDAVConfigSection: View {
    
    @Binding var config: WebDAVConfig
    @Binding var selection: StorageLocation?
    @State private var password = ""
    
    var body: some View {
        Section("WebDAV-Server") {
            TextField("Name", text: $config.name)
            TextField("URL", text: $config.url)
                .keyboardType(.URL)
            TextField("Benutzername", text: $config.username)
            SecureField("Passwort", text: $password)
        }
        
        Section {
            Button(action: save) {
                HStack {
                    Spacer()
                    Text("Speichern")
                    Spacer()
                }
            }
            .disabled(config.url.isEmpty)
        }
    }
    
    private func save() {
        selection = .webdav(config)
    }
}

// MARK: - Cloud Config Section

struct CloudConfigSection: View {
    
    @Binding var config: CloudConfig
    @Binding var selection: StorageLocation?
    
    var body: some View {
        Section("Cloud-Speicher") {
            Picker("Provider", selection: $config.provider) {
                ForEach(CloudProvider.allCases, id: \.self) { provider in
                    HStack {
                        Image(systemName: provider.icon)
                        Text(provider.rawValue)
                    }
                    .tag(provider)
                }
            }
            .pickerStyle(.menu)
            
            TextField("Pfad (optional)", text: $config.path)
            
            Button(action: connectOAuth) {
                HStack {
                    Spacer()
                    Text("Mit \(config.provider.rawValue) verbinden")
                    Spacer()
                }
            }
        }
        
        Section {
            Button(action: save) {
                HStack {
                    Spacer()
                    Text("Speichern")
                    Spacer()
                }
            }
        }
    }
    
    private func connectOAuth() {
        // TODO: OAuth-Flow für Cloud-Provider
        // Für jetzt nur Placeholder
    }
    
    private func save() {
        selection = .cloud(config)
    }
}

#Preview {
    StoragePickerView(selection: .constant(nil))
}
