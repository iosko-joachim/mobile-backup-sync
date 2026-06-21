//
//  KeychainStore.swift
//  MobileBackupSync
//
//  Created on 2026-06-21.
//

import Foundation
import Security

/// Secure storage for passwords and credentials in iOS Keychain
class KeychainStore {
    
    static let shared = KeychainStore()
    
    private let serviceName = Bundle.main.bundleIdentifier ?? "de.jomative.mobilebackup"
    
    private init() {}
    
    /// Store password for a given account/service
    func savePassword(_ password: String, for account: String, service: String? = nil) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service ?? serviceName,
            kSecAttrAccount as String: account,
            kSecValueData as String: password.data(using: .utf8)!
        ]
        
        // Delete existing item first
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }
    
    /// Retrieve password for a given account/service
    func getPassword(for account: String, service: String? = nil) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service ?? serviceName,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let password = String(data: data, encoding: .utf8) else {
            throw KeychainError.notFound
        }
        
        return password
    }
    
    /// Delete password for a given account/service
    func deletePassword(for account: String, service: String? = nil) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service ?? serviceName,
            kSecAttrAccount as String: account
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }
    
    /// Check if password exists for account
    func hasPassword(for account: String, service: String? = nil) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service ?? serviceName,
            kSecAttrAccount as String: account,
            kSecReturnData as String: false
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        return status == errSecSuccess
    }
    
    /// List all stored accounts
    func getAllAccounts() -> [String] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let items = result as? [[String: Any]] else {
            return []
        }
        
        return items.compactMap { $0[kSecAttrAccount as String] as? String }
    }
}

/// Keychain errors
enum KeychainError: Error {
    case saveFailed(OSStatus)
    case notFound
    case deleteFailed(OSStatus)
    case unknown
    
    var localizedDescription: String {
        switch self {
        case .saveFailed(let status):
            return "Speichern fehlgeschlagen: \(status)"
        case .notFound:
            return "Eintrag nicht gefunden"
        case .deleteFailed(let status):
            return "Löschen fehlgeschlagen: \(status)"
        case .unknown:
            return "Unbekannter Fehler"
        }
    }
}
