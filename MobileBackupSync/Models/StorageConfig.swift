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

/// FTP-Konfiguration (plain FTP, passiv; FTPS noch nicht enthalten).
struct FTPConfig: Codable, Equatable {
    let id: String
    var name: String
    var host: String
    var port: Int
    var path: String
    var username: String
    var passwordInKeychain: Bool

    init(
        id: String = UUID().uuidString,
        name: String = "",
        host: String = "",
        port: Int = 21,
        path: String = "",
        username: String = "",
        passwordInKeychain: Bool = true
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.path = path
        self.username = username
        self.passwordInKeychain = passwordInKeychain
    }
}
