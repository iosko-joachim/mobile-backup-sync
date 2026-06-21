# Statusbericht – Mobile Backup & Sync

Stand: 2026-06-21

## Zusammenfassung

Lauffähiger MVP für **Einweg-Backup von einem lokalen iOS-Ordner auf eine
SMB-Freigabe** (und zurück als Restore). Die App ist auf diesen Scope reduziert;
SSH-, WebDAV- und Cloud-Ziele sind bewusst nicht enthalten.

## Funktionsumfang (implementiert)

- **Speicherorte:** lokaler Ordner (über `UIDocumentPicker`, security-scoped) und
  SMB/CIFS (AMSMB2). Beide als Quelle **oder** Ziel kombinierbar.
- **Vergleich:** rekursiv, Zuordnung über relativen Pfad, Kriterien Größe →
  Änderungsdatum (2 s Toleranz) → optional SHA-256-Hash.
- **Vorschau (Dry Run):** Vergleichsergebnis vor dem Transfer; optionaler
  Probelauf ohne Schreibzugriff.
- **Transfer:** dateibasiert über temporäre Datei (kein Vollständig-in-den-RAM),
  Retry-Logik (3 Versuche) **mit Reconnect** gegen „broken pipe",
  **Zeitstempel-Erhaltung am Ziel** (stabiler inkrementeller Abgleich),
  Fortschritts- und Fehlerprotokoll.
- **Sicherheit:** SMB-Passwörter im Keychain (`AfterFirstUnlockThisDeviceOnly`),
  SMB-Signing erzwungen.
- **Persistenz:** Quelle und Ziel überleben App-Neustarts (lokale Ordner als
  Security-Scoped Bookmark, SMB-Konfiguration als JSON; Passwort bleibt im Keychain).
- **Modi:** Backup (Quelle → Ziel), Mirror (zusätzlich Löschen am Ziel),
  Bidirektional (kennzeichnet Konflikte; keine automatische Auflösung).
- **Protokoll:** In-Memory + Datei-Log, exportierbar über den Protokoll-Tab.

## Architektur

```
App        MobileBackupSyncApp → ContentView (Tabs: Backup, Jobs, Protokoll, Einstellungen)
Models     AppState, FileItem, SyncJob, StorageConfig (SMB)
Core       SyncEngine → CompareEngine, TransferManager
Providers  StorageProvider (Protokoll) → LocalStorageProvider, SMBStorageProvider
Services   HashService, KeychainStore, SettingsStore, LogService
Vendor     AMSMB2 (libsmb2)
```

Jeder Provider kennt seine Wurzel; alle Pfade im Protokoll sind relativ dazu.
Dadurch ist der `TransferManager` provider-agnostisch.

## Bekannte Grenzen / nicht enthalten

- Keine Hintergrund-/Zeitplan-Ausführung (Backup wird manuell gestartet).
- Toggles „nur WLAN", „nur beim Laden", parallele Transfers und Verschlüsselung
  sind **nicht** umgesetzt und daher nicht in den Einstellungen sichtbar.
- Bidirektionaler Modus löst Konflikte nicht automatisch auf.
- SSH/WebDAV/Cloud sind nicht implementiert (siehe README → Ausblick).
- **FTP** ist bewusst nicht übernommen (NAS-backup unterstützt SMB **und** FTP als
  FRITZ!Box-Fallback). Für reine SMB-NAS unkritisch; bei FTP-only-Zielen fehlt es.

## Build

```
xcodegen generate
xcodebuild -scheme MobileBackupSync -destination 'generic/platform=iOS Simulator' build
```
