//
//  StorageConfig.swift
//  MobileBackupSync
//
//  Created on 2026-06-21.
//

import Foundation

/// SMB-Konfiguration
struct SMBConfig: Codable, Equatable {
    let id: String
    var name: String
    var host: String
    var port: Int
    var share: String
    var path: String
    var username: String
    var passwordInKeychain: Bool
    
    var url: String {
        "smb://\(host):\(port)/\(share)/\(path)"
    }
    
    init(
        id: String = UUID().uuidString,
        name: String = "",
        host: String = "",
        port: Int = 445,
        share: String = "",
        path: String = "",
        username: String = "",
        passwordInKeychain: Bool = true
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.share = share
        self.path = path
        self.username = username
        self.passwordInKeychain = passwordInKeychain
    }
}

/// SSH/SFTP-Konfiguration
struct SSHConfig: Codable, Equatable {
    let id: String
    var name: String
    var host: String
    var port: Int
    var path: String
    var username: String
    var authMethod: SSHAuthMethod
    
    var url: String {
        "sftp://\(host):\(port)/\(path)"
    }
    
    init(
        id: String = UUID().uuidString,
        name: String = "",
        host: String = "",
        port: Int = 22,
        path: String = "",
        username: String = "",
        authMethod: SSHAuthMethod = .password
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.path = path
        self.username = username
        self.authMethod = authMethod
    }
}

/// SSH-Authentifizierungsmethode
enum SSHAuthMethod: Codable, Equatable {
    case password
    case key(String) // Key-Name im Keychain
    
    var displayName: String {
        switch self {
        case .password: return "Passwort"
        case .key: return "SSH-Key"
        }
    }
}

/// WebDAV-Konfiguration
struct WebDAVConfig: Codable, Equatable {
    let id: String
    var name: String
    var url: String
    var username: String
    var passwordInKeychain: Bool
    
    init(
        id: String = UUID().uuidString,
        name: String = "",
        url: String = "",
        username: String = "",
        passwordInKeychain: Bool = true
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.username = username
        self.passwordInKeychain = passwordInKeychain
    }
}

/// Cloud-Konfiguration
struct CloudConfig: Codable, Equatable {
    let id: String
    var name: String
    var provider: CloudProvider
    var path: String
    
    init(
        id: String = UUID().uuidString,
        name: String = "",
        provider: CloudProvider = .googleDrive,
        path: String = ""
    ) {
        self.id = id
        self.name = name
        self.provider = provider
        self.path = path
    }
}

/// Unterstützte Cloud-Provider
enum CloudProvider: String, Codable, Equatable, CaseIterable {
    case googleDrive = "Google Drive"
    case oneDrive = "OneDrive"
    case dropbox = "Dropbox"
    case icloud = "iCloud Drive"
    
    var icon: String {
        switch self {
        case .googleDrive: return "circle.fill" // TODO: Eigene Icons
        case .oneDrive: return "cloud.fill"
        case .dropbox: return "square.fill"
        case .icloud: return "icloud.fill"
        }
    }
}
