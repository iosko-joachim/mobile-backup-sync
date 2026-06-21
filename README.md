# Mobile Backup & Sync

Eine native iOS-App (SwiftUI) für Backup und Dateivergleich zwischen dem iPhone/iPad
und einem Netzwerkspeicher (SMB- oder FTP-NAS).

## Status

**MVP – lauffähig.** Einweg-Backup von einem lokalen Ordner auf eine SMB-Freigabe
oder einen FTP-Server (und zurück als Restore), mit Vorschau und Protokoll. Details
siehe [REPORT.md](REPORT.md).

## Funktionen

- Lokaler Ordner (iOS Files / `UIDocumentPicker`) als Quelle oder Ziel
- SMB/CIFS-Freigabe als Quelle oder Ziel (AMSMB2 / libsmb2)
- FTP-Server als Quelle oder Ziel (plain, passiv, über `Network.framework`; FTPS folgt)
- Rekursiver Vergleich nach Größe, Datum und optional SHA-256-Hash
- Vorschau vor dem Kopieren, optionaler Dry Run
- Modi: Backup, Mirror (mit Löschen am Ziel), Bidirektional (Konflikt-Markierung)
- Passwörter im iOS-Keychain
- Protokoll mit Export

## Architektur

```
+-----------------------------------------------------------+
|  UI (SwiftUI)                                             |
|  Tabs: Backup · Jobs · Protokoll · Einstellungen          |
+-----------------------------------------------------------+
|  Core                                                     |
|  SyncEngine → CompareEngine · TransferManager             |
+-----------------------------------------------------------+
|  Storage Providers                                        |
|  StorageProvider (Protokoll)                              |
|   ├─ LocalStorageProvider (iOS Dateisystem)               |
|   ├─ SMBStorageProvider   (SMB/CIFS via AMSMB2)           |
|   └─ FTPStorageProvider   (FTP via Network.framework)     |
+-----------------------------------------------------------+
|  Services                                                 |
|  HashService · KeychainStore · SettingsStore · LogService |
+-----------------------------------------------------------+
```

Jeder Provider kennt seine Wurzel; alle Pfade sind relativ dazu, wodurch der
`TransferManager` provider-agnostisch über eine temporäre Datei kopiert.

## Technologie-Stack

| Komponente          | Technologie            |
|---------------------|------------------------|
| App                 | Swift, SwiftUI         |
| Mindest-iOS-Version | iOS 16                 |
| SMB                 | AMSMB2 (libsmb2)       |
| FTP                 | Network.framework      |
| Hashing             | CryptoKit (SHA-256)    |
| Key-Storage         | Keychain               |
| Projektgenerierung  | XcodeGen               |

## Build

Voraussetzung: Xcode 16+, [XcodeGen](https://github.com/yonaskolb/XcodeGen)
(`brew install xcodegen`).

```sh
xcodegen generate
open MobileBackupSync.xcodeproj
```

Das Xcode-Projekt wird generiert und ist nicht eingecheckt (siehe `.gitignore`).

## Ausblick (nicht im MVP)

- **FTPS (FTP über TLS)** — verschlüsselte Variante des vorhandenen FTP-Providers
  (explizit `AUTH TLS`); nötig für FTP über unsichere Netze
- Weitere Ziele: SSH/SFTP, WebDAV (Nextcloud), Cloud-Anbieter
- **iPad: BeyondCompare-artige Vergleichsansicht** — Zweispalter mit ausgerichteten
  Zeilen, Datei-Detail/Inhalts-Diff und Vergleich verschiedener Stände (Telefon
  behält die Listenansicht). Siehe IMPLEMENTIERUNGSPLAN § 2.6
- Geplante/Hintergrund-Ausführung, „nur im WLAN / beim Laden"
- Optionale Verschlüsselung, parallele Transfers
- Automatische Konfliktauflösung im bidirektionalen Modus

## License

Proprietary

## Related

- [IMPLEMENTIERUNGSPLAN.md](IMPLEMENTIERUNGSPLAN.md) – Roadmap (inkl. Korrekturen aus dem Gegencheck)
- [Legacy-Projekt: NAS-backup](https://github.com/iosko-joachim/NAS-backup) – bestehende SMB-/FTP-Backup-Lösung (TestFlight)
