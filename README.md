# Mobile Backup & Sync

Eine native iOS-App (SwiftUI) für Backup, Synchronisation und Dateivergleich zwischen mobilen Geräten und verschiedenen Speicherzielen.

## Status

**Phase:** Entwicklung (iOS-First)

Geplante Funktionen siehe [IMPLEMENTIERUNGSPLAN.md](../IMPLEMENTIERUNGSPLAN.md).

## Geplante Architektur

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
|  - SMBStorageProvider (SMB/CIFS)                                      |
|  - SSHStorageProvider (SFTP + Server-Helper)                          |
|  - WebDAVStorageProvider (Nextcloud, etc.)                            |
|  - CloudStorageProvider (Google Drive, OneDrive, Dropbox)             |
+-----------------------------------------------------------------------+
|  Infrastructure                                                       |
|  - HashService (SHA-256, MD5)                                         |
|  - EncryptionService (optional, AES-256)                              |
|  - LogService                                                         |
|  - SchedulerService (Hintergrundtasks)                                |
+-----------------------------------------------------------------------+
```

## MVP-Scope (Phase 1)

1. Quelle: lokaler iPhone-Speicher
2. Ziel: SMB-Server
3. Einweg-Backup
4. Vergleich nach Datum, Größe und optional Hash
5. Vorschau vor Kopiervorgang
6. Protokoll nach Abschluss
7. Einfache Fehlerbehandlung
8. Manuelles Starten des Backups

## Technologie-Stack

| Komponente | Technologie |
|------------|-------------|
| iOS App | Swift, SwiftUI |
| Mindest-iOS-Version | iOS 16 |
| Architektur | MVVM + Clean Architecture |
| SMB | MobileSMB / SMBJ |
| SSH/SFTP | NMSSH |
| Hashing | CryptoKit (native) |
| Key-Storage | Keychain (native) |

## Projektstruktur (geplant)

```
MobileBackupSync/
├── App/
│   └── MobileBackupSyncApp.swift
├── Models/
│   ├── FileItem.swift
│   ├── SyncJob.swift
│   └── SyncResult.swift
├── Core/
│   ├── SyncEngine.swift
│   ├── CompareEngine.swift
│   ├── TransferManager.swift
│   └── ConflictResolver.swift
├── Providers/
│   ├── LocalStorageProvider.swift
│   ├── SMBStorageProvider.swift
│   ├── SSHStorageProvider.swift
│   ├── WebDAVStorageProvider.swift
│   └── CloudStorageProvider.swift
├── Services/
│   ├── HashService.swift
│   ├── EncryptionService.swift
│   ├── LogService.swift
│   └── SchedulerService.swift
├── Views/
│   ├── Dashboard/
│   ├── Compare/
│   ├── Settings/
│   └── Logs/
└── Utilities/
    └── Extensions/
```

## License

Proprietary

## Related

- [Legacy-Projekt](https://github.com/iosko-joachim/NAS-backup) - Bestehende SMB-Backup-Lösung
- [Implementierungsplan](../IMPLEMENTIERUNGSPLAN.md) - Detaillierter Entwicklungsplan
