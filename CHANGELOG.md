# Changelog

Alle wesentlichen Änderungen an Mobile Backup & Sync werden in dieser Datei dokumentiert.

## [Unreleased]

### Hinzugefügt

- Grundgerüst der iOS-App mit SwiftUI
- Tab-Navigation (Backup, Vergleich, Jobs, Einstellungen)
- Datenmodelle für Sync-Jobs, Dateien und Storage-Konfigurationen
- Core-Engine-Interfaces (SyncEngine, CompareEngine, TransferManager, ConflictResolver)
- StorageProvider-Protokoll für verschiedene Speicherziele

### Geplant

- SMB-Provider-Implementierung
- Lokaler Dateisystem-Provider
- Vergleichs-Engine mit Hash-Unterstützung
- Transfer-Engine mit Retry-Logik
- Keychain-Integration für Passwörter

---

## Versionen

Die Versionsnummerierung folgt dem Semantic Versioning Schema (MAJOR.MINOR.PATCH):

- **MAJOR**: Inkompatible API-Änderungen
- **MINOR**: Neue Funktionen (abwärtskompatibel)
- **PATCH**: Fehlerkorrekturen (abwärtskompatibel)
