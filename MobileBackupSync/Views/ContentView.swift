//
//  ContentView.swift
//  MobileBackupSync
//
//  Created on 2026-06-21.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Backup", systemImage: "externaldrive")
                }
                .tag(0)
            
            CompareView()
                .tabItem {
                    Label("Vergleich", systemImage: "doc.text.magnifyingglass")
                }
                .tag(1)
            
            JobsView()
                .tabItem {
                    Label("Jobs", systemImage: "list.bullet")
                }
                .tag(2)
            
            SettingsView()
                .tabItem {
                    Label("Einstellungen", systemImage: "gear")
                }
                .tag(3)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
