//
//  SettingsStore.swift
//  MobileBackupSync
//
//  Created on 2026-06-21.
//

import Foundation

/// Persistiert App-Einstellungen und Job-Konfigurationen
class SettingsStore {
    
    static let shared = SettingsStore()
    
    private let userDefaults = UserDefaults.standard
    private let keychain = KeychainStore.shared
    
    private enum Keys {
        static let jobs = "jobs"
        static let selectedSource = "selectedSource"
        static let selectedDestination = "selectedDestination"
        static let smbPasswords = "smbPasswords"
        static let sshKeys = "sshKeys"
    }
    
    private init() {}
    
    // MARK: - Jobs
    
    /// Speichert einen Job (einfache Persistenz via Name)
    func saveJob(_ job: SyncJob) {
        // TODO: Vollständige Job-Persistenz implementieren
        // Für jetzt nur als Placeholder
        var jobNames = getAllJobNames()
        if !jobNames.contains(job.name) {
            jobNames.append(job.name)
            userDefaults.set(jobNames, forKey: Keys.jobs)
        }
    }
    
    /// Holt alle gespeicherten Job-Namen
    func getAllJobNames() -> [String] {
        return userDefaults.stringArray(forKey: Keys.jobs) ?? []
    }
    
    /// Holt alle gespeicherten Jobs (Placeholder)
    func getAllJobs() -> [SyncJob] {
        // TODO: Vollständige Implementierung
        return []
    }
    
    /// Löscht einen Job
    func deleteJob(id: UUID) {
        // TODO: Implementierung
    }
    
    /// Holt einen spezifischen Job
    func getJob(id: UUID) -> SyncJob? {
        // TODO: Implementierung
        return nil
    }
    
    // MARK: - SMB Passwords
    
    /// Speichert SMB-Passwort im Keychain
    func saveSMBPassword(host: String, username: String, password: String) {
        let account = "smb:\(host):\(username)"
        try? keychain.savePassword(password, for: account)
    }
    
    /// Holt SMB-Passwort aus Keychain
    func getSMBPassword(host: String, username: String) -> String? {
        let account = "smb:\(host):\(username)"
        return try? keychain.getPassword(for: account)
    }
    
    /// Löscht SMB-Passwort
    func deleteSMBPassword(host: String, username: String) {
        let account = "smb:\(host):\(username)"
        try? keychain.deletePassword(for: account)
    }
    
    // MARK: - SSH Keys
    
    /// Speichert SSH-Key im Keychain
    func saveSSHKey(name: String, privateKey: String) {
        let account = "ssh:\(name)"
        try? keychain.savePassword(privateKey, for: account)
    }
    
    /// Holt SSH-Key aus Keychain
    func getSSHKey(name: String) -> String? {
        let account = "ssh:\(name)"
        return try? keychain.getPassword(for: account)
    }
    
    /// Löscht SSH-Key
    func deleteSSHKey(name: String) {
        let account = "ssh:\(name)"
        try? keychain.deletePassword(for: account)
    }
    
    // MARK: - App Settings
    
    /// WLAN-Only Einstellung
    var wifiOnly: Bool {
        get { userDefaults.bool(forKey: "wifiOnly") }
        set { userDefaults.set(newValue, forKey: "wifiOnly") }
    }
    
    /// Nur beim Laden einstellen
    var powerOnly: Bool {
        get { userDefaults.bool(forKey: "powerOnly") }
        set { userDefaults.set(newValue, forKey: "powerOnly") }
    }
    
    /// Nach Hash vergleichen
    var compareByHash: Bool {
        get { userDefaults.bool(forKey: "compareByHash") }
        set { userDefaults.set(newValue, forKey: "compareByHash") }
    }
    
    /// Verschlüsselung aktivieren
    var encryptFiles: Bool {
        get { userDefaults.bool(forKey: "encryptFiles") }
        set { userDefaults.set(newValue, forKey: "encryptFiles") }
    }
    
    /// Dry Run Modus
    var dryRun: Bool {
        get { userDefaults.bool(forKey: "dryRun") }
        set { userDefaults.set(newValue, forKey: "dryRun") }
    }
    
    /// Maximale parallele Transfers
    var maxParallelTransfers: Int {
        get { userDefaults.integer(forKey: "maxParallelTransfers") }
        set { userDefaults.set(newValue, forKey: "maxParallelTransfers") }
    }
    
    /// Letzte verwendete Quelle
    var selectedSource: String? {
        get { userDefaults.string(forKey: Keys.selectedSource) }
        set { userDefaults.set(newValue, forKey: Keys.selectedSource) }
    }
    
    /// Zuletzt verwendetes Ziel
    var selectedDestination: String? {
        get { userDefaults.string(forKey: Keys.selectedDestination) }
        set { userDefaults.set(newValue, forKey: Keys.selectedDestination) }
    }
    
    // MARK: - Reset
    
    /// Alle Einstellungen zurücksetzen
    func reset() {
        let dictionary = userDefaults.dictionaryRepresentation()
        dictionary.keys.forEach { key in
            userDefaults.removeObject(forKey: key)
        }
    }
}
