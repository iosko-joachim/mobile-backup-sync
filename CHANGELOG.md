# Changelog

Alle wesentlichen Änderungen an Mobile Backup & Sync werden in dieser Datei dokumentiert.

## [Unreleased]

### Hinzugefügt

- Lauffähiger MVP: Einweg-Backup lokaler Ordner → SMB/FTP (und Restore)
- FTP-Provider (plain, passiv) über `Network.framework` — rekursives Listing
  (MLSD mit LIST-Fallback), STOR/RETR mit Fortschritt, MKD, DELE, MFMT (best effort)
- Rekursiver Vergleich mit Zuordnung über relativen Pfad
- Optionaler SHA-256-Hash-Vergleich
- Dry Run (Vorschau ohne Schreibzugriff)
- Transfer über temporäre Datei (RAM-schonend) mit Retry-Logik
- Protokoll-Tab mit Export
- Persistenz der Quelle/Ziel über Neustarts (lokale Ordner als Security-Scoped
  Bookmark, SMB-Konfiguration als JSON)
- Korrigierter Implementierungsplan im Repo (`IMPLEMENTIERUNGSPLAN.md`)

### Geändert

- SMB-Provider lädt Passwort jetzt aus dem Keychain (vorher fest leer)
- StorageProvider-Protokoll vereinheitlicht: wurzelbasiert, relative Pfade
- Keychain-Items mit `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`
- Lokaler Zugriff hält security-scoped Ressource über den gesamten Lauf

### Entfernt

- Doppeltes AMSMB2-Vendoring
- Nicht implementierte Ziele (SSH/WebDAV/Cloud) aus Modellen und UI
- Redundanter Vergleich-Tab, leere „Neuer Job"-Ansicht, ungenutzter ConflictResolver
- Irreführende Einstellungen ohne Wirkung (parallele Transfers, WLAN/Laden, Verschlüsselung)
- Schein-MD5 (gab SHA-256 zurück)

### Behoben

- Transfer-Pfadlogik (Quelle/Ziel über relativen Pfad statt absolutem Quellpfad)
- Erfolgreicher Retry wurde fälschlich als Fehler gewertet
- UI war nicht an die Engine angeschlossen (Backup/Vergleich taten nichts)
- Build scheiterte an Test-Targets ohne Quellen
- **Zeitstempel-Erhaltung am Ziel** (SetInfo via `setAttributes`): ohne sie galt
  beim nächsten Lauf jede Datei als „geändert" und wurde erneut kopiert — der
  inkrementelle Abgleich war faktisch wirkungslos (Regression ggü. NAS-backup)
- **Reconnect vor Retry**: nach einem Fehler wird die Verbindung neu aufgebaut
  (gegen „broken pipe" bei großen Läufen) statt auf der toten Verbindung erneut
  zu versuchen

---

## Versionen

Die Versionsnummerierung folgt dem Semantic Versioning Schema (MAJOR.MINOR.PATCH):

- **MAJOR**: Inkompatible API-Änderungen
- **MINOR**: Neue Funktionen (abwärtskompatibel)
- **PATCH**: Fehlerkorrekturen (abwärtskompatibel)
