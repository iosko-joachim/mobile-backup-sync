//
//  SettingsStore.swift
//  MobileBackupSync
//
//  Created on 2026-06-21.
//

import Foundation

/// Persistiert sensible Zugangsdaten (Passwörter im Keychain).
///
/// Einfache Schalter (Hash-Vergleich, Dry Run) liegen direkt als `@AppStorage`
/// in den Views und brauchen hier keine Spiegelung.
final class SettingsStore {

    static let shared = SettingsStore()

    private let keychain = KeychainStore.shared

    private init() {}

    // MARK: - SMB-Passwörter

    private func smbAccount(host: String, username: String) -> String {
        "smb:\(host):\(username)"
    }

    /// Speichert ein SMB-Passwort im Keychain.
    func saveSMBPassword(host: String, username: String, password: String) {
        try? keychain.savePassword(password, for: smbAccount(host: host, username: username))
    }

    /// Liest ein SMB-Passwort aus dem Keychain.
    func getSMBPassword(host: String, username: String) -> String? {
        try? keychain.getPassword(for: smbAccount(host: host, username: username))
    }

    /// Löscht ein SMB-Passwort.
    func deleteSMBPassword(host: String, username: String) {
        try? keychain.deletePassword(for: smbAccount(host: host, username: username))
    }

    // MARK: - FTP-Passwörter

    private func ftpAccount(host: String, username: String) -> String {
        "ftp:\(host):\(username)"
    }

    /// Speichert ein FTP-Passwort im Keychain.
    func saveFTPPassword(host: String, username: String, password: String) {
        try? keychain.savePassword(password, for: ftpAccount(host: host, username: username))
    }

    /// Liest ein FTP-Passwort aus dem Keychain.
    func getFTPPassword(host: String, username: String) -> String? {
        try? keychain.getPassword(for: ftpAccount(host: host, username: username))
    }

    /// Löscht ein FTP-Passwort.
    func deleteFTPPassword(host: String, username: String) {
        try? keychain.deletePassword(for: ftpAccount(host: host, username: username))
    }
}
