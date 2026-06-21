# Mobile Backup & Sync - Projekt-Report

**Stand:** 2026-06-21  
**Repository:** https://github.com/iosko-joachim/mobile-backup-sync  
**Status:** MVP implementiert und build-fähig

---

## 1. Projekt-Übersicht

Mobile Backup & Sync ist eine native iOS-Anwendung (SwiftUI) für Backup, Synchronisation und Dateivergleich zwischen mobilen Geräten und verschiedenen Speicherzielen.

### Produktpositionierung

> Schlanke Backup-, Sync- und Vergleichslösung für mobile Geräte, lokale Netzwerkspeicher und ausgewählte Cloud-Ziele.

### Plattform-Strategie

| Phase | Plattform | Status |
|-------|-----------|--------|
| MVP + Phase 1-2 | iOS | ✅ Implementiert |
| Phase 3+ | iOS | 🟡 In Entwicklung |
| Nach Launch | Android | ⚪ Geplant |

---

## 2. Implementierte Features (MVP)

### ✅ Abgeschlossene Komponenten

| Bereich | Komponente | Status | Beschreibung |
|---------|------------|--------|--------------|
| **Storage** | LocalStorageProvider | ✅ | Lokaler Dateizugriff über iOS Files App |
| **Storage** | SMBStorageProvider | ✅ | SMB/CIFS mit AMSMB2-Bibliothek |
| **Storage** | StorageProvider Protocol | ✅ | Einheitliches Interface für alle Provider |
| **Core** | SyncEngine | ✅ | Orchestrierung aller Sync-Operationen |
| **Core** | CompareEngine | ✅ | Dateivergleich (Größe, Datum, Hash) |
| **Core** | TransferManager | ✅ | Transfer mit Retry-Logik (3 Versuche) |
| **Core** | ConflictResolver | ✅ | Konfliktauflösung mit Regeln |
| **Services** | HashService | ✅ | SHA-256 Hashing (chunked für große Dateien) |
| **Services** | LogService | ✅ | Strukturierte Protokollierung + File-Output |
| **Services** | KeychainStore | ✅ | Sichere Passwort-Speicherung im Keychain |
| **Services** | SettingsStore | ✅ | App-Einstellungen und Job-Persistenz |
| **Utilities** | LocalNetworkAuthorizer | ✅ | iOS Local Network Permission Handler |
| **Utilities** | DocumentPicker | ✅ | SwiftUI Wrapper für UIDocumentPicker |
| **UI** | DashboardView | ✅ | Hauptbildschirm mit Backup-Steuerung |
| **UI** | StoragePickerView | ✅ | Speicherort-Auswahl (Local, SMB, SSH, WebDAV, Cloud) |
| **UI** | CompareView | ✅ | Vergleichsansicht mit Filter |
| **UI** | JobsView | ✅ | Job-Verwaltung und Historie |
| **UI** | SettingsView | ✅ | App-Einstellungen |
| **UI** | LogView | ✅ | Protokoll-Ansicht mit Export |

### 🎯 MVP-Funktionsumfang

1. ✅ Quelle: Lokaler iPhone-Speicher (Files App)
2. ✅ Ziel: SMB-Server (NAS, FRITZ!Box)
3. ✅ Einweg-Backup
4. ✅ Vergleich nach Datum, Größe und optional Hash
5. ✅ Vorschau vor Kopiervorgang (Dry Run)
6. ✅ Protokoll nach Abschluss
7. ✅ Fehlerbehandlung mit Retry-Logik
8. ✅ Manuelles Starten des Backups
9. ✅ Passwort-Speicherung im Keychain
10. ✅ Local Network Permission für iOS

---

## 3. Technische Architektur

### Architektur-Übersicht

```
+-----------------------------------------------------------------------+
|                        iOS Applikation (SwiftUI)                      |
+-----------------------------------------------------------------------+
|  UI Layer                                                             |
|  - Dashboard                                                          |
|  - Vergleichsansicht                                                  |
|  - Konfiguration                                                      |
|  - Protokoll                                                          |
+-----------------------------------------------------------------------+
|  Core Layer (Swift)                                                   |
|  - SyncEngine                                                         |
|  - CompareEngine                                                      |
|  - TransferManager                                                    |
|  - ConflictResolver                                                   |
+-----------------------------------------------------------------------+
|  Storage Providers                                                    |
|  - LocalStorageProvider (iOS Dateisystem)                             |
|  - SMBStorageProvider (AMSMB2 / libsmb2)                              |
|  - SSHStorageProvider (geplant)                                       |
|  - WebDAVStorageProvider (geplant)                                    |
|  - CloudStorageProvider (geplant)                                     |
+-----------------------------------------------------------------------+
|  Infrastructure                                                       |
|  - HashService (SHA-256)                                              |
|  - EncryptionService (geplant, AES-256)                               |
|  - LogService                                                         |
|  - KeychainStore                                                      |
|  - SettingsStore                                                      |
+-----------------------------------------------------------------------+
```

### Technologie-Stack

| Komponente | Technologie | Version |
|------------|-------------|---------|
| Sprache | Swift | 5.0+ |
| UI-Framework | SwiftUI | iOS 16+ |
| Architektur | MVVM + Clean Architecture | - |
| SMB-Bibliothek | AMSMB2 (libsmb2) | Latest |
| Hashing | CryptoKit | Native |
| Key-Storage | Keychain | Native |
| Build-Tool | XcodeGen | Latest |

### Abhängigkeiten

| Bibliothek | Lizenz | Zweck |
|------------|--------|-------|
| AMSMB2 | LGPL-2.1 (dynamisch gelinkt) | SMB/CIFS Protokoll |
| CryptoKit | Apple | SHA-256 Hashing |
| SwiftUI | Apple | Benutzeroberfläche |

---

## 4. Projektstruktur

```
mobile-backup-sync/
├── MobileBackupSync/
│   ├── App/
│   │   └── MobileBackupSyncApp.swift
│   ├── Models/
│   │   ├── AppState.swift
│   │   ├── SyncJob.swift
│   │   ├── FileItem.swift
│   │   └── StorageConfig.swift
│   ├── Core/
│   │   ├── SyncEngine.swift
│   │   ├── CompareEngine.swift
│   │   ├── TransferManager.swift
│   │   └── ConflictResolver.swift
│   ├── Providers/
│   │   ├── StorageProvider.swift
│   │   ├── LocalStorageProvider.swift
│   │   └── SMBStorageProvider.swift
│   ├── Services/
│   │   ├── HashService.swift
│   │   ├── LogService.swift
│   │   ├── KeychainStore.swift
│   │   └── SettingsStore.swift
│   ├── Util/
│   │   ├── LocalNetwork.swift
│   │   └── DocumentPicker.swift
│   ├── Views/
│   │   ├── ContentView.swift
│   │   ├── Dashboard/
│   │   ├── Compare/
│   │   ├── Jobs/
│   │   ├── Settings/
│   │   └── Logs/
│   └── Info.plist
├── Vendor/
│   └── AMSMB2/               # SMB-Bibliothek mit libsmb2
├── MobileBackupSyncTests/
├── MobileBackupSyncUITests/
├── project.yml               # XcodeGen Konfiguration
├── README.md
├── CHANGELOG.md
├── REPORT.md                 # Dieses Dokument
└── .gitignore
```

---

## 5. Build-Status

### Aktuelle Build-Konfiguration

| Einstellung | Wert |
|-------------|------|
| Mindest-iOS-Version | iOS 16.0 |
| Zielgerät | iPhone & iPad |
| Code Signing | Automatic (Team: XV75SD8TB6) |
| Bundle ID | de.jomative.mobilebackup |

### Build-Ergebnis

```
✅ BUILD SUCCEEDED
```

Getestet mit:
- Xcode 26+
- iOS Simulator 26.5 (iPhone 15)
- Code Signing: Disabled für Build-Test

---

## 6. Roadmap

### Phase 1: MVP (✅ Abgeschlossen)

- [x] Projekt-Setup mit XcodeGen
- [x] Core-Engine Implementierung
- [x] LocalStorageProvider
- [x] SMBStorageProvider mit AMSMB2
- [x] HashService
- [x] LogService
- [x] KeychainStore
- [x] SettingsStore
- [x] Complete SwiftUI UI
- [x] DocumentPicker Integration
- [x] Local Network Permission

### Phase 2: Erweiterungen (🟡 In Entwicklung)

- [ ] Bidirektionale Synchronisation
- [ ] Konflikterkennung und -auflösung (UI)
- [ ] Restore-Funktion
- [ ] Geplante Backups
- [ ] Backup nur im heimischen WLAN
- [ ] Backup nur bei Akkuladung
- [ ] Unterstützung externer USB-Speicher
- [ ] Verbesserte Protokollierung mit Statistiken

### Phase 3: Cloud & SSH (⚪ Geplant)

- [ ] Google Drive Integration
- [ ] iCloud Drive Integration
- [ ] OneDrive Integration
- [ ] Dropbox Integration
- [ ] Nextcloud/WebDAV
- [ ] SSH/SFTP mit serverseitiger Hash-Berechnung
- [ ] Versionierung
- [ ] Verschlüsselte Backups (AES-256)
- [ ] Inkrementelle Backups
- [ ] Parallele Transfers
- [ ] Fortsetzen abgebrochener Kopiervorgänge

### Phase 4: Professionalisierung (⚪ Geplant)

- [ ] Deduplizierung
- [ ] Kompression
- [ ] Bandbreitenbegrenzung
- [ ] Enterprise-Features (MDM)
- [ ] Monitoring & Alerting
- [ ] App Store Launch

---

## 7. Offene Punkte & TODOs

### Technisch

| Priorität | Thema | Beschreibung |
|-----------|-------|--------------|
| Hoch | SMB-Testing | Test gegen reales NAS/FRITZ!Box |
| Hoch | Local Network Dialog | Bonjour-Integration für iOS-Permission |
| Mittel | SSH-Provider | Vollständige SFTP-Implementierung |
| Mittel | Cloud-OAuth | OAuth-Flows für Cloud-Provider |
| Niedrig | Verschlüsselung | AES-256 für sensible Backups |

### UI/UX

| Priorität | Thema | Beschreibung |
|-----------|-------|--------------|
| Hoch | DocumentPicker | Security-Scoped Bookmarks persistieren |
| Mittel | Fortschritts-Anzeige | Detaillierte Transfer-Statistiken |
| Mittel | Konflikt-UI | Manuelle Konfliktauflösung |
| Niedrig | Dark Mode | System Dark Mode Support |

### Testing

| Priorität | Thema | Beschreibung |
|-----------|-------|--------------|
| Hoch | Unit Tests | Core-Engine Tests |
| Hoch | Integration Tests | SMB-Transfer Tests |
| Mittel | UI Tests | Haupt-Workflows automatisiert |
| Mittel | Performance | Große Dateimengen (>10.000 Dateien) |

---

## 8. Bekannte Einschränkungen

### iOS-spezifisch

1. **Hintergrund-Backups**: Echtes Weiterkopieren bei gesperrtem Bildschirm ist auf iOS für SMB nicht möglich (Background-Transfers nur für HTTP). Lösung: Bildschirm während Transfer wachhalten.

2. **Local Network Permission**: iOS verlangt Nutzerinteraktion für lokalen Netzwerkzugriff. Wird über Bonjour-Browse initiiert.

3. **Dateisystem-Zugriff**: iOS Sandboxing erfordert DocumentPicker für externen Zugriff.

### SMB-spezifisch

1. **Signing**: SMB-Signing muss client-seitig erzwungen werden für FRITZ!Box-Kompatibilität.

2. **Löschen von Dateien**: Aktuelle AMSMB2-Version unterstützt kein direktes Löschen (workaround nötig).

3. **Freier Speicherplatz**: Keine direkte API in AMSMB2 für SMB-FreeSpace-Abfrage.

---

## 9. Rechtliche Hinweise

### Lizenzen

| Komponente | Lizenz | Hinweis |
|------------|--------|---------|
| Eigener Code | Proprietary | - |
| AMSMB2/libsmb2 | LGPL-2.1 | Dynamisch gelinkt, App-Store-konform |
| CryptoKit | Apple | Native iOS-Framework |
| SwiftUI | Apple | Native iOS-Framework |

### Datenschutz (CH - revDSG)

- Passwörter werden im iOS Keychain gespeichert (hardware-verschlüsselt)
- Keine Datenübertragung an Drittanbieter
- Lokale Verarbeitung aller Daten
- Local Network Zugriff nur mit Nutzer-Einwilligung

---

## 10. Kontakt & Support

**Entwickler:** Joachim Köhler  
**Team-ID:** XV75SD8TB6  
**Bundle-ID:** de.jomative.mobilebackup  

**Repository:** https://github.com/iosko-joachim/mobile-backup-sync  
**Issues:** https://github.com/iosko-joachim/mobile-backup-sync/issues  

---

## 11. Dokumenten-Historie

| Version | Datum | Autor | Änderung |
|---------|-------|-------|----------|
| 1.0 | 2026-06-21 | - | Erster Report nach MVP-Abschluss |

---

*Dieser Report dokumentiert den aktuellen Entwicklungsstand des Mobile Backup & Sync Projekts.*
