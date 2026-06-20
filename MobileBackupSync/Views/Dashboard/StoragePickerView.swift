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
                    LocalStoragePickerRow(selection: $selection)
                case .smb:
                    SMBConfigPickerRow(selection: $selection)
                case .ssh:
                    SSHConfigPickerRow(selection: $selection)
                case .webdav:
                    WebDAVConfigPickerRow(selection: $selection)
                case .cloud:
                    CloudConfigPickerRow(selection: $selection)
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

/// Lokaler Speicher
struct LocalStoragePickerRow: View {
    @Binding var selection: StorageLocation?
    @State private var selectedURL: URL?
    
    var body: some View {
        Section("Lokaler Speicher") {
            Button("Ordner auswählen") {
                // TODO: DocumentPicker öffnen
            }
            
            if let url = selectedURL {
                HStack {
                    Image(systemName: "folder.fill")
                    Text(url.lastPathComponent)
                }
            }
        }
    }
}

/// SMB-Konfiguration
struct SMBConfigPickerRow: View {
    @Binding var selection: StorageLocation?
    @State private var config = SMBConfig()
    
    var body: some View {
        Section("SMB-Server") {
            TextField("Name", text: $config.name)
            TextField("Host (IP oder Hostname)", text: $config.host)
            TextField("Freigabe", text: $config.share)
            TextField("Pfad", text: $config.path)
            TextField("Benutzername", text: $config.username)
            SecureField("Passwort", text: .constant(""))
            
            Button("Verbindung testen") {
                // TODO: SMB-Verbindung testen
            }
        }
    }
}

/// SSH-Konfiguration
struct SSHConfigPickerRow: View {
    @Binding var selection: StorageLocation?
    @State private var config = SSHConfig()
    
    var body: some View {
        Section("SSH/SFTP-Server") {
            TextField("Name", text: $config.name)
            TextField("Host", text: $config.host)
            TextField("Pfad", text: $config.path)
            TextField("Benutzername", text: $config.username)
            SecureField("Passwort", text: .constant(""))
        }
    }
}

/// WebDAV-Konfiguration
struct WebDAVConfigPickerRow: View {
    @Binding var selection: StorageLocation?
    @State private var config = WebDAVConfig()
    
    var body: some View {
        Section("WebDAV-Server") {
            TextField("Name", text: $config.name)
            TextField("URL", text: $config.url)
            TextField("Benutzername", text: $config.username)
            SecureField("Passwort", text: .constant(""))
        }
    }
}

/// Cloud-Konfiguration
struct CloudConfigPickerRow: View {
    @Binding var selection: StorageLocation?
    @State private var config = CloudConfig()
    
    var body: some View {
        Section("Cloud-Speicher") {
            Picker("Provider", selection: $config.provider) {
                ForEach(CloudProvider.allCases, id: \.self) { provider in
                    Text(provider.rawValue).tag(provider)
                }
            }
            TextField("Pfad", text: $config.path)
            
            Button("Mit \(config.provider.rawValue) verbinden") {
                // TODO: OAuth-Flow starten
            }
        }
    }
}

#Preview {
    StoragePickerView(selection: .constant(nil))
}
