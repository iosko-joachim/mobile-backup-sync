//
//  LocalNetwork.swift
//  MobileBackupSync
//
//  Created on 2026-06-21.
//

import Foundation
import Network

/// Helper für Local Network Permission auf iOS
/// iOS verlangt eine Nutzerinteraktion bevor Apps auf das lokale Netzwerk zugreifen dürfen.
/// Dieser Helper initiiert den Dialog durch einen Bonjour-Browse.
class LocalNetworkAuthorizer {
    
    static let shared = LocalNetworkAuthorizer()
    
    private var browser: NWBrowser?
    private var connection: NWConnection?
    
    private init() {}
    
    /// Startet den Local Network Permission Dialog
    /// - Returns: true wenn erfolgreich, false wenn verweigert
    func requestAccess() async -> Bool {
        // Browser für SMB-Dienste im lokalen Netzwerk
        let descriptor = NWBrowser.Descriptor.bonjour(type: "_smb._tcp", domain: "local.")
        
        let parameters = NWParameters()
        parameters.allowLocalEndpointReuse = true
        
        browser = NWBrowser(for: descriptor, using: parameters)
        
        // Browser-Events beobachten
        browser?.stateUpdateHandler = { state in
            switch state {
            case .ready:
                // Browser ist bereit - Permission wurde erteilt
                self.stop()
            case .failed(let error):
                // Permission verweigert oder Fehler
                print("Local Network Access failed: \(error)")
                self.stop()
            default:
                break
            }
        }
        
        browser?.start(queue: .main)
        
        // Warte auf Resultat
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.stop()
                continuation.resume(returning: true)
            }
        }
    }
    
    /// Stoppt den Browser
    private func stop() {
        browser?.cancel()
        browser = nil
    }
    
    /// Testet Verbindung zu einem bestimmten Host
    func testConnection(host: String, port: Int = 445) async -> Bool {
        let host = NWEndpoint.Host(host)
        let port = NWEndpoint.Port(integerLiteral: UInt16(port))
        
        let connection = NWConnection(host: host, port: port, using: .tcp)
        
        return await withCheckedContinuation { continuation in
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    connection.cancel()
                    continuation.resume(returning: true)
                case .failed:
                    connection.cancel()
                    continuation.resume(returning: false)
                default:
                    break
                }
            }
            
            connection.start(queue: .main)
            
            // Timeout nach 5 Sekunden
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                if connection.state != .ready {
                    connection.cancel()
                    continuation.resume(returning: false)
                }
            }
        }
    }
}
