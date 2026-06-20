//
//  MobileBackupSyncApp.swift
//  MobileBackupSync
//
//  Created on 2026-06-21.
//

import SwiftUI

@main
struct MobileBackupSyncApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
    }
}
