# Implementierungsplan: Mobile Backup- und Sync-Applikation

> **Korrekturhinweise (Stand 2026-06-21, nach Gegencheck mit dem real ausgelieferten
> Vorgänger [NAS-backup](https://github.com/iosko-joachim/NAS-backup) und dem MVP `mobile-backup-sync`):**
>
> 1. **SMB-Bibliothek:** Die ursprünglich genannten Kandidaten *MobileSMB / SMBJ* sind
>    untauglich — **SMBJ ist eine Java/Android-Bibliothek** und auf iOS nicht nutzbar.
>    Bewährt (TestFlight-erprobt im Vorgängerprojekt) ist **AMSMB2 (libsmb2)**. Inline korrigiert.
> 2. **libsmb2-Signing (kritisch):** SMB auf iOS scheitert reproduzierbar an
>    `STATUS_ACCESS_DENIED`, weil libsmb2 unter SMB 3.1.1 CREATE/opendir-PDUs **unsigniert**
>    sendet, wenn der Server Signing nur „enabled" (nicht „required") meldet. Fix:
>    Signing client-seitig erzwingen (`smb2_set_sign(1)` bzw. `forceSMBSigning = true`).
>    Dieser Punkt gehört zwingend in Machbarkeit + Risiko (siehe ergänzte Einträge).
> 3. **Zeitstempel-Erhaltung am Ziel** (`SetInfo`/`setAttributes`) ist **Voraussetzung**
>    für inkrementelles Backup — ohne sie gilt jede Datei beim nächsten Lauf als geändert.
>    Als Akzeptanzkriterium im MVP ergänzt.
> 4. **FTP** existiert im Vorgänger als verifizierter FRITZ!Box-Fallback (SMB **und** FTP).
>    Im MVP `mobile-backup-sync` als eigener `FTPStorageProvider` (plain/passiv über
>    `Network.framework`) **umgesetzt**; FTPS/TLS steht noch aus.
> 5. **MD5** aus dem HashService gestrichen — für Integrität wertlos, nur SHA-256.
> 6. **iOS-Realität:** „Geplante Backups" im Hintergrund, direkter USB-Zugriff mit
>    Hot-Plug und SSID-Whitelist sind auf iOS stark eingeschränkt — als Best-Effort
>    bzw. mit Berechtigungs-/Entitlement-Hürden gekennzeichnet.

## Projektübersicht

**Ziel:** Entwicklung einer mobilen Backup-, Sync- und Vergleichsapplikation für iOS (Primärplattform) mit späterer Android-Erweiterung.

**Ausgangslage:** Ein funktionierender, real ausgelieferter Kern existiert bereits
(iPhone-Daten → NAS, **SMB und FTP**, end-to-end an einer FRITZ!Box verifiziert; robocopy-artig
inkrementell mit Zeitstempel-Erhaltung und Reconnect-Retry).

**Produktpositionierung:** Schlanke Backup-, Sync- und Vergleichslösung für mobile Geräte, lokale Netzwerkspeicher und ausgewählte Cloud-Ziele.

**Plattform-Strategie:**

| Phase | Plattform | Fokus |
|-------|-----------|-------|
| MVP + Phase 1-2 | iOS | Hauptentwicklung |
| Phase 3+ | iOS | Feature-Complete |
| Nach Launch | Android | Portierung basierend auf iOS-Erfahrungen |

---

## Architekturübersicht

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
|  - HashService (SHA-256)                                             |
|  - EncryptionService (optional, AES-256)                              |
|  - LogService                                                         |
|  - SchedulerService (Hintergrundtasks)                                |
+-----------------------------------------------------------------------+
```

### Android-Portierung (spätere Phase)

Nach Abschluss der iOS-Entwicklung kann eine Android-Version als separate Implementierung erfolgen:

| Komponente | iOS | Android (später) |
|------------|-----|------------------|
| UI | SwiftUI | Jetpack Compose |
| Core Logic | Swift | Kotlin (Portierung) |
| Storage Providers | Native iOS | Native Android |
| Architektur | MVVM | MVVM (ähnlich) |

**Vorteil dieses Ansatzes:**
- Fokus auf eine Plattform für saubere Implementierung
- Schnellere Time-to-Market
- Lessons Learned aus iOS fließen in Android ein
- Kein KMP-Overhead in früher Phase

---

## Positionierung & Abgrenzung

### Wettbewerb (iOS-rclone-Frontends)

- **Rclone UI** (`rclone-ui/rclone-ui`, OSS, ~2 $, iOS/macOS): **Generalist** —
  Fernsteuerung/Schaltzentrale für vorhandene rclone-Remotes (Copy/Sync/Bisync als
  Kommandos, Job-Monitor). Breit, aber pro Use-Case flach; setzt rclone-Vorwissen voraus.
- **ccViewer / CryptCloudViewer** (`lithium0003/ccViewer`, OSS): **veraltet**,
  Viewer-/crypt-zentriert (auch SMB), kein Backup-/Vergleichs-Workflow.
- Niemand bietet eine **BeyondCompare-artige** Vergleichs-/Merge-Ansicht.

### Unsere Abgrenzung (das Moat)

1. **Fokussierter Anwendungsfall** (Mobilgerät ↔ Heim-NAS sichern & vergleichen) mit
   geführtem Ablauf — kein generischer Remote-Manager.
2. **BeyondCompare-artige Vergleichs-/Merge-UX** (§2.6) — das zentrale, unbesetzte
   Differenzierungsmerkmal.
3. **Native, adaptive iOS/iPad-UX** (Zweispalter, Files-Integration).
4. **Verifizierter LAN/Heim-NAS-Pfad** (SMB/FTP gegen FRITZ!Box, libsmb2-Signing) —
   getestet, nicht „eins von 70 ungetesteten Backends".
5. **Engine-Symmetrie als System**: in-App (Vordergrund) + Steuerung eines `rcd`
   auf dem NAS (headless) aus einer App.
6. **CH/Privacy-Default**: self-host, Daten bleiben zuhause.

> **Ehrlich:** Rclone UI ist bereits da, billig, plattformübergreifend; ccViewer deckt
> SMB+Cloud schon ab. Unsere Wette liegt auf **UX-Tiefe (Vergleich/Merge) + Fokus +
> verifizierte Qualität**, nicht auf Backend-Breite — Breite gewinnt rclone immer.

### Backend-Strategie: kuratieren statt 70 Häkchen

70 Backends kann niemand testen oder supporten → für ein Produkt eine QA-/Support-
Haftung. Daher:

- **Offiziell unterstützt & gegen echte Geräte getestet** (Kern): Local, SMB, FTP,
  WebDAV/Nextcloud, iCloud Drive, ggf. Dropbox/Drive.
- **Der Rest: „experimentell via rclone"** — funktioniert, aber ohne Support-Versprechen.
- Macht aus der Testlast ein **Qualitätsversprechen**: „Was wir listen, testen wir real."

### Rolle von librclone (nicht ignorieren!)

**librclone ist nicht der Konkurrent, sondern unser Motor für die Cloud-Erweiterung.**
Klare Arbeitsteilung:

- **Kern-Transporte = eigene, verifizierte Provider** (Local, SMB via libsmb2/Signing,
  FTP) — der getestete Heim-NAS-Pfad bleibt unter unserer Kontrolle.
- **Cloud-Backends = via librclone** als `RcloneProvider` (Google Drive, OneDrive,
  Dropbox, S3, …) — so nehmen wir weitere Cloud-Speicher auf, ohne jeden Anbieter-SDK
  selbst zu bauen/pflegen.
- So kombinieren wir **unsere Stärke** (verifizierter LAN-/Backup-Pfad + UX) mit
  **rclones Stärke** (Backend-Breite). Details/Trade-offs siehe §3.1.

---

## Phase 0: Vorbereitung und Analyse

**Dauer:** 1-2 Wochen

### Aufgaben

- [ ] **Rechtliche Prüfung (CH)**
  - [ ] Datenschutzanforderungen (revDSG) klären
  - [ ] Urheberrechtliche Aspekte bei Dateikopien prüfen
  - [ ] App Store Guidelines für Backup-Apps analysieren
  - [ ] Nutzungsbedingungen der Cloud-Provider prüfen

- [ ] **Technische Machbarkeitsstudie (iOS-Fokus)**
  - [ ] iOS Files App / File Provider Framework evaluieren
  - [x] SMB-Bibliothek für iOS: **AMSMB2 (libsmb2)** gewählt/erprobt (NICHT SMBJ — das ist Android/Java)
    - [ ] libsmb2-Signing erzwingen verifizieren (`forceSMBSigning`, gegen `STATUS_ACCESS_DENIED`)
  - [ ] SSH/SFTP-Bibliothek evaluieren (NMSSH, SwiftSSH)
  - [ ] Cloud-SDKs prüfen (Google, Microsoft, Dropbox APIs)
  - [ ] Hintergrundtask-Limits auf iOS dokumentieren
  - [ ] iCloud-Integration Möglichkeiten prüfen

- [ ] **Anforderungsanalyse**
  - [ ] Zielgruppe definieren (Poweruser vs. Normalnutzer)
  - [ ] Use Cases priorisieren
  - [ ] iOS-Einschränkungen dokumentieren
  - [ ] Mindestanforderungen an iOS-Version festlegen
  - [ ] iPad-Unterstützung prüfen

### Deliverables

- [ ] Rechtliches Memo (Datenschutz, Urheberrecht)
- [ ] Technische Machbarkeitsstudie (iOS)
- [ ] Anforderungsdokument (Lastenheft)
- [ ] Architektur-Entscheidungsprotokoll

---

## Phase 0b: Android-Vorbereitung (nach iOS-Launch)

**Dauer:** 1-2 Wochen

### Aufgaben

- [ ] Android-Machbarkeitsstudie
  - [ ] Storage Access Framework evaluieren
  - [ ] SMB-Bibliothek für Android testen (SMBJ)
  - [ ] SSH/SFTP-Bibliothek evaluieren (JSch, Apache MINA)
  - [ ] Background Work Manager evaluieren
  - [ ] Scoped Storage (Android 10+) analysieren

- [ ] Portierungs-Planung
  - [ ] Architektur-Entscheidung: Native Android vs. KMP
  - [ ] Feature-Priorisierung für Android
  - [ ] Mindestanforderungen an Android-Version festlegen

### Deliverables

- [ ] Android-Machbarkeitsstudie
- [ ] Portierungs-Konzept
- [ ] Android-Spezifika Dokument

---

## Phase 1: MVP (Minimum Viable Product)

**Dauer:** 6-8 Wochen

### Scope

1. Quelle: lokaler iPhone-Speicher
2. Ziel: SMB-Server
3. Einweg-Backup
4. Vergleich nach Datum, Größe und optional Hash
5. Vorschau vor Kopiervorgang
6. Protokoll nach Abschluss
7. Einfache Fehlerbehandlung
8. Manuelles Starten des Backups

### Aufgaben

#### 1.1 Projekt-Setup

- [ ] Xcode-Projekt erstellen (iOS 16+)
- [ ] Swift Package Manager konfigurieren
- [ ] CI/CD Pipeline einrichten (GitHub Actions / Bitrise)
- [ ] Test-Target einrichten
- [ ] Code Style Guidelines definieren

#### 1.2 Core-Engine

- [ ] `SyncEngine` Basis-Implementierung
  - [ ] Interface-Definition
  - [ ] Status-Machine (idle, comparing, transferring, done, error)
  - [ ] Fortschritts-Tracking
  - [ ] Abbruch-Handling

- [ ] `CompareEngine` Implementierung
  - [ ] Vergleich nach Dateiname
  - [ ] Vergleich nach Größe
  - [ ] Vergleich nach Änderungsdatum
  - [ ] Optional: Vergleich nach Hash (lokal)
  - [ ] Ergebnis-Datenstruktur (neu, geändert, gelöscht, gleich)

- [ ] `TransferManager` Implementierung
  - [ ] Datei-Kopierlogik
  - [ ] Fortschritts-Callback
  - [ ] Retry-Logik bei Fehlern
  - [ ] Bandbreiten-Monitoring

#### 1.3 Storage Providers

- [ ] `LocalStorageProvider`
  - [ ] Dateisystem-Zugriff (Photos, Files, App-Daten)
  - [ ] Metadaten-Auslesung (Größe, Datum, Hash)
  - [ ] Verzeichnis-Rekursion

- [ ] `SMBStorageProvider`
  - [ ] SMB-Verbindungsaufbau
  - [ ] Authentication (Benutzer/Passwort)
  - [ ] Datei-Upload
  - [ ] Verzeichnis-Struktur anlegen
  - [ ] Verbindungstest

#### 1.4 UI (SwiftUI)

- [ ] App-Grundgerüst
  - [ ] Tab-Bar Navigation
  - [ ] Settings Screen

- [ ] Dashboard
  - [ ] Quellen-Auswahl
  - [ ] Ziel-Konfiguration (SMB)
  - [ ] Start-Button
  - [ ] Fortschritts-Anzeige

- [ ] Vergleichsansicht
  - [ ] Side-by-side Darstellung
  - [ ] Farbcodierung (neu/grün, geändert/gelb, gelöscht/rot)
  - [ ] Filter-Optionen
  - [ ] Dry-Run Toggle

- [ ] Protokoll-Ansicht
  - [ ] Transfer-Log
  - [ ] Fehler-Log
  - [ ] Export-Funktion

#### 1.5 Infrastruktur

- [ ] `LogService`
  - [ ] Strukturierte Logs
  - [ ] Log-Level (debug, info, warn, error)
  - [ ] Log-Export

- [ ] `HashService`
  - [ ] SHA-256 Implementierung
  - [ ] Incremental Hashing für große Dateien
  - [ ] Performance-Optimierung

#### 1.6 Testing

- [ ] Unit Tests für Core-Engine
- [ ] Unit Tests für Storage Providers
- [ ] UI Tests für Haupt-Workflows
- [ ] Manuelle Tests mit realem SMB-Server

### Deliverables

- [ ] Funktionierende MVP-App (iOS)
- [ ] Testberichte
- [ ] Benutzerdokumentation (Basis)
- [ ] App Store Submission Prep

---

## Phase 2: Erweiterungsstufe 1

**Dauer:** 8-10 Wochen

### Scope

- Bidirektionales Kopieren
- Konflikterkennung und -auflösung
- Ordnervergleich
- **iPad: BeyondCompare-artige Vergleichsansicht** (Zweispalter, Datei-Detail, Stände)
- Restore-Funktion
- Geplante Backups *(iOS: nur Best-Effort — BGProcessingTask/Background Fetch geben
  keine garantierte Laufzeit für lange SMB-Transfers; realistisch „Trigger beim
  App-Start im passenden WLAN" statt echtem Scheduling)*
- Backup nur im heimischen WLAN *(SSID-Auslesen erfordert auf iOS Standort-Berechtigung
  bzw. Network-Extension-Entitlement)*
- Backup nur bei Akkuladung
- Unterstützung externer USB-Speicher *(iOS: nur über Document Picker/FileProvider —
  kein direkter Block-/FS-Zugriff, kein Hot-Plug-Event-Handling)*
- Verbesserte Protokollierung

### Aufgaben

#### 2.1 Bidirektionale Synchronisation

- [ ] `SyncEngine` erweitern
  - [ ] Bidirektions-Modus
  - [ ] Erkennung von Änderungen auf beiden Seiten
  - [ ] Sync-Regeln (neuer gewinnt, älter gewinnt, manuell)

- [ ] `ConflictResolver`
  - [ ] Konflikterkennung (beide Seiten geändert)
  - [ ] Automatische Auflösung (nach Regel)
  - [ ] Manuelle Auflösung (UI-Dialog)
  - [ ] Beide behalten (Umbenennung)

#### 2.2 Restore-Funktion

- [ ] Restore-UI
  - [ ] Backup-Zeitpunkt auswählen
  - [ ] Dateien/Ordner auswählen
  - [ ] Zielort wählen
  - [ ] Überschreib-Bestätigung

- [ ] Restore-Engine
  - [ ] Rückkopie SMB → iOS
  - [ ] Dateiwiederherstellung
  - [ ] Berechtigungs-Handling

#### 2.3 Automatisierung

- [ ] `SchedulerService`
  - [ ] Hintergrund-Task-Scheduling
  - [ ] iOS Background Fetch Integration
  - [ ] Push-Trigger (optional)

- [ ] Trigger-Bedingungen
  - [ ] WLAN-Erkennung (SSID-Whitelist)
  - [ ] Ladezustand (Netzteil vs. Batterie)
  - [ ] Uhrzeit (zeitgesteuert)
  - [ ] Kombinationen (UND/ODER)

#### 2.4 Externe Speicher

- [ ] `USBStorageProvider`
  - [ ] USB-C / Lightning Adapter-Erkennung
  - [ ] Dateisystem-Zugriff
  - [ ] Hot-Plug Handling

- [ ] UI für externe Speicher
  - [ ] Auswahl als Quelle
  - [ ] Auswahl als Ziel

#### 2.5 Verbesserte Protokollierung

- [ ] Detaillierte Transfer-Logs
- [ ] Statistiken (Dauer, Durchsatz, Fehlerquote)
- [ ] Graphische Aufbereitung
- [ ] Export (PDF, CSV)

#### 2.6 iPad: BeyondCompare-artige Vergleichsansicht

Vision: auf dem iPad eine vollwertige, zweispaltige Vergleichsdarstellung wie
BeyondCompare — verschiedene Stände gegeneinander zeigen, auf Dateiebene
hineinzoomen und die unterschiedlichen Daten sichtbar machen. Das Telefon behält
die schlanke Listenansicht (starker Platz-Kompromiss).

Architektur-Vorteil: Quelle/Ziel werden bereits über den `relativePath` als
gemeinsamen Schlüssel abgeglichen — genau die Grundlage für ein Zweispalter-Layout.

- [ ] **Adaptive UI** über `horizontalSizeClass`: iPad (`regular`) → Zweispalter,
  Telefon (`compact`) → bestehende Liste. Eine Codebasis, kein Fork.
- [ ] **Gepaartes Vergleichsmodell**: CompareEngine je Pfad **beide** Seiten
  ausgeben (Größe/Datum/Hash links *und* rechts) + Status + Richtung, statt nur
  einer Seite wie heute.
- [ ] **Zweispalter mit ausgerichteten Zeilen**: eine gemeinsame Zeilenliste rendert
  linke Zelle · Mitte (Richtungs-/Status-Gutter) · rechte Zelle → Ausrichtung
  garantiert ohne Scroll-Synchronisation. Fehlende Seite = Platzhalterzeile.
- [ ] **Ordnerbaum** (`OutlineGroup`) zum Auf-/Zuklappen statt Flachliste.
- [ ] **Farbcodierung + Richtungspfeile** (neu →, geändert ≠, nur Ziel ←, gleich =).
- [ ] **Datei-Detail (Drill-down)**: bei Auswahl einer Datei beide Metadatensätze
  nebeneinander (Größe, Datum, Hash) und — wo sinnvoll — inhaltlicher Vergleich:
  Text-Diff bei Textdateien, Vorschau bei Bildern.
- [ ] **Verschiedene Stände vergleichen**: mehrere Backup-Zeitpunkte/Snapshots
  gegeneinander stellen (setzt Versionierung aus Phase 3.4 voraus).
- [ ] **Optional interaktiv**: pro Datei Richtung/Aktion wählbar (→, ←, überspringen,
  beide behalten) — die Engine muss dafür einen pro-Datei-Plan akzeptieren.
- [ ] **Dateien bearbeiten/mergen** (höchste Ausbaustufe, wie BeyondCompares Editor):
  - [ ] Text-Merge zeilenweise: einzelne Unterschiede von links nach rechts (oder
        umgekehrt) übernehmen, manuell editieren, Ergebnis zurückschreiben.
  - [ ] Schreib-Pfad: Datei laden → im Editor ändern → über den Provider
        (Local/SMB/FTP) zurückschreiben, mit Zeitstempel-Erhaltung und
        Konflikt-Sicherung (Original vorher sichern / nicht blind überschreiben).
  - [ ] Grenzen ehrlich halten: sinnvoll v. a. für Text-/Konfigdateien; für Binär-/
        Mediendateien nur Anzeige/Vorschau, kein zeilenweiser Merge.
  - [ ] Sicherheitsnetz: Bearbeiten ist destruktiv → Bestätigung, optional Backup
        der Originalversion vor dem Überschreiben.

### Deliverables

- [ ] Bidirektionale Sync-Funktion
- [ ] Restore-Funktion
- [ ] Automatisierte Backups
- [ ] USB-Speicher-Support
- [ ] iPad-Zweispalter (BeyondCompare-artig)
- [ ] Erweiterte Test-Suite

---

## Phase 2b: Android-MVP (nach iOS-Phase 2)

**Dauer:** 8-10 Wochen

### Scope

- Android-Portierung der MVP-Funktionen
- SMB-Backup
- Vergleich
- Manuelles Starten

### Aufgaben

- [ ] Android-Projekt-Setup
- [ ] UI-Implementierung (Jetpack Compose)
- [ ] Storage Providers für Android
- [ ] Testing auf Android-Geräten
- [ ] Play Store Submission Prep

### Deliverables

- [ ] Android-MVP-App
- [ ] Play Store Submission Prep

---

## Phase 3: Erweiterungsstufe 2 (Cloud & SSH)

**Dauer:** 10-12 Wochen

### Scope

- Google Drive
- iCloud Drive
- OneDrive
- Dropbox
- Nextcloud/WebDAV
- SSH/SFTP
- Serverseitige Hash-Berechnung
- Versionierung
- Verschlüsselte Backups
- Inkrementelle Backups
- Parallele Transfers
- Fortsetzen abgebrochener Kopiervorgänge

### Aufgaben

#### 3.1 Cloud-Provider Integration

> **Umsetzungs-Entscheidung — zwei Wege.** Vor dem Bau abwägen:
>
> **(A) Einzel-SDKs pro Anbieter** (wie unten gelistet): volle Kontrolle, native
> Auth, aber je Anbieter mehrere Tage Arbeit + Pflege.
>
> **(B) `librclone`-Embedding** (Alternative, oft attraktiver): rclones Bibliotheks-API
> (`RcloneRPC`, MIT) via `gomobile bind` → `Rclone.xcframework` → Swift-Bridge.
> - **Gewinn:** ~70 Backends sofort (Drive, Dropbox, OneDrive, S3, WebDAV/Nextcloud …),
>   ohne jeden OAuth/SDK selbst zu bauen; als `RcloneProvider` hinter das
>   `StorageProvider`-Protokoll hängbar.
> - **Symmetrie:** `librclone` (in-App) und `rclone rcd` (auf dem NAS, siehe Konzept
>   „Headless Protokoll-Konverter") sprechen **dieselbe RC-API** → eine Bedienschicht,
>   zwei Laufzeiten (lokal/Vordergrund vs. headless/24-7).
> - **Hebt iOS-Hintergrund-Limits NICHT auf:** in-App-rclone taugt nur für
>   Vordergrund-Transfers (Bildschirm wach), nicht für unbeaufsichtigten Dauerlauf.
> - **Kosten/Risiken:** +30–50 MB Binär (per Build-Tags trimmbar), zweite Runtime
>   (Go-GC), gomobile/Go-on-iOS-Toolchain-Pflege (arm64 Gerät + Simulator-Slices),
>   OAuth-Glue über `ASWebAuthenticationSession`, Config/Tokens in Keychain.
> - **Umgeht NICHT** Googles Restricted-Scope-Verifizierung für eine veröffentlichte App.
>
> **Deckt auch SMB & FTP ab.** rclone hat seit v1.61 ein **SMB-Backend** (SMB 2/3,
> Signing/Encryption) und ein FTP-Backend — SMB jedoch über die reine Go-Lib
> `go-smb2`, **nicht** über libsmb2. Heißt: librclone könnte den **kompletten**
> Transport-Stack stellen (Local/SMB/FTP/Cloud) und sowohl das AMSMB2-Vendoring als
> auch den eigenen FTP-Provider ersetzen. Caveat: `go-smb2` ≠ der erprobte
> libsmb2-Pfad → FRITZ!Box/Signing **neu verifizieren**, bevor man konsolidiert (das
> war der teuer gelöste Knackpunkt des Vorgängers).
>
> **Strategische Option — „rclone-Frontend" (ernsthaft prüfen).** *Credit where credit
> is due:* wenn rclone die Transporte systematisch löst, sollten wir das nicht
> ignorieren — es kann die Architektur bewusst kippen. Die App würde dann ein
> **nativer iOS/iPad-Frontend über die rclone-Engine** (librclone in-App + `rclone rcd`
> auf dem NAS, **dieselbe RC-API**), statt eigener Transport-Reimplementierungen.
> - **Was wegfällt:** vendortes libsmb2, eigener FTP-Provider, jede Anbieter-OAuth/SDK,
>   eigene Vergleichs-/Hash-/Retry-Mechanik — kommt alles aus rclone (breit gepflegt).
> - **Was UNSER Mehrwert bleibt:** die native UX — v. a. die BeyondCompare-artige
>   Vergleichs-/Merge-Ansicht (§2.6), Bedienung, Schweizer-freundliche Konfiguration,
>   Steuerung **lokaler *und* headless** Läufe aus einer App.
> - **Was sich NICHT ändert:** iOS-Hintergrund-Limits (in-App nur Vordergrund),
>   Store-/Google-Verifizierung, Binärgröße/gomobile-Pflege. Und: rclone liefert
>   `check`/Listing/Hashes, aber **kein** interaktives Merge — die BeyondCompare-Tiefe
>   bleibt unsere UI-Schicht auf rclones Daten.
> - **Nächster Schritt:** ein librclone-Spike (ein Cloud-Backend + ein echter SMB-Lauf
>   gegen die FRITZ!Box), um die Konsolidierung zu validieren, bevor man sich festlegt.

- [ ] `CloudStorageProvider` Basis-Interface (bzw. `RcloneProvider` bei Variante B)

- [ ] Google Drive
  - [ ] OAuth 2.0 Implementierung
  - [ ] Google Drive SDK Integration
  - [ ] API Quota Management
  - [ ] Rate Limiting

- [ ] Microsoft OneDrive
  - [ ] Microsoft Auth Library (MSAL)
  - [ ] OneDrive API (Graph API)
  - [ ] Business/Personal Support

- [ ] Dropbox
  - [ ] Dropbox SDK
  - [ ] OAuth Flow
  - [ ] Chunked Upload für große Dateien

- [ ] Nextcloud/WebDAV
  - [ ] WebDAV Client Implementierung
  - [ ] Basic Auth + Token Auth
  - [ ] Selbst-gehostete Instanzen Support

- [ ] iCloud Drive
  - [ ] CloudKit Integration
  - [ ] Files App Integration

#### 3.2 FTPS (FTP über TLS)

- [ ] `FTPStorageProvider` um TLS erweitern (Basis-FTP ist im MVP bereits umgesetzt)
  - [ ] Explizites `AUTH TLS` auf dem Steuerkanal
  - [ ] TLS auch auf dem Datenkanal (`PROT P`)
  - [ ] Zertifikatsprüfung / Umgang mit selbstsignierten Server-Zertifikaten
  - [ ] UI-Schalter „FTP über TLS (FTPS)" in der FTP-Sektion
  - Begründung: Plain FTP überträgt Zugangsdaten unverschlüsselt; FTPS ist die
    Voraussetzung für FTP über unsichere Netze.

#### 3.3 SSH/SFTP Provider

- [ ] `SSHStorageProvider`
  - [ ] SSH-Verbindungsaufbau
  - [ ] Authentication (Passwort, Key)
  - [ ] SFTP-Protokoll Implementierung
  - [ ] Key-Management (Import/Export)

- [ ] Server-Hilfsprogramm
  - [ ] Shell-Skript für Hash-Berechnung
  - [ ] Auto-Deploy auf Server
  - [ ] Kompatibilitäts-Check (sha256sum verfügbar?)
  - [ ] Fallback auf client-seitige Berechnung

- [ ] SSH-UI
  - [ ] Server-Konfiguration
  - [ ] Key-Generator
  - [ ] Verbindungstest
  - [ ] Terminal-Log (Debug)

#### 3.4 Versionierung

- [ ] Versions-Tracking
  - [ ] Metadaten-Speicherung pro Backup
  - [ ] Versions-Historie
  - [ ] Diff zwischen Versionen

- [ ] Version-Restore
  - [ ] Einzelne Version wiederherstellen
  - [ ] Kompletten Stand wiederherstellen

#### 3.5 Verschlüsselung

- [ ] `EncryptionService`
  - [ ] AES-256 Verschlüsselung
  - [ ] Key-Derivation (PBKDF2)
  - [ ] Key-Speicherung (Keychain)
  - [ ] Optional: User-Passwort

- [ ] Verschlüsselte Backups
  - [ ] Pre-Transfer Verschlüsselung
  - [ ] Metadaten-Verschlüsselung
  - [ ] Secure Key-Export

#### 3.6 Performance-Optimierung

- [ ] Inkrementelle Backups
  - [ ] Change-Tracking
  - [ ] Nur geänderte Dateien transferieren
  - [ ] Block-level Incremental (später)

- [ ] Parallele Transfers
  - [ ] Multi-Threaded Upload/Download
  - [ ] Connection Pooling
  - [ ] Bandbreiten-Management

- [ ] Resume-Funktion
  - [ ] Unterbrochene Transfers fortsetzen
  - [ ] Checkpointing
  - [ ] Partial File Handling

### Deliverables

- [ ] Cloud-Provider Support (mind. 3)
- [ ] SSH/SFTP mit Server-Helper
- [ ] Verschlüsselung
- [ ] Versionierung
- [ ] Performance-optimierte Transfers

---

## Phase 3b: Android-Erweiterungen (nach iOS-Phase 3)

**Dauer:** 10-12 Wochen

### Scope

- Android-Portierung der Cloud-Features
- SSH/SFTP für Android
- Verschlüsselung (Android Keystore)

### Deliverables

- [ ] Android mit Cloud-Support
- [ ] Android mit SSH/SFTP
- [ ] Feature-Parität mit iOS (soweit möglich)

---

## Phase 4: Professionalisierung (iOS)

**Dauer:** 6-8 Wochen

### Scope

- Deduplizierung
- Kompression
- Bandbreitenbegrenzung
- Enterprise-Features
- Monitoring & Alerting
- App Store Launch

### Aufgaben

#### 4.1 Deduplizierung

- [ ] Content-Addressable Storage
  - [ ] Chunk-basierte Deduplizierung
  - [ ] Hash-Index
  - [ ] Speicher-Statistiken

#### 4.2 Kompression

- [ ] Transparente Kompression
  - [ ] Algorithmus-Auswahl (ZIP, LZ4, ZSTD)
  - [ ] Kompressions-Level
  - [ ] CPU vs. Größe Trade-off

#### 4.3 Bandbreiten-Management

- [ ] Upload/Download-Limits
- [ ] Zeitbasierte Regeln (nachts schneller)
- [ ] Adaptive Bandbreite (Netzwerk-Qualität)

#### 4.4 Enterprise-Features (optional)

- [ ] MDM-Support
- [ ] Zentrale Konfiguration
- [ ] Bulk-Deployment
- [ ] Audit-Logs

#### 4.5 Monitoring & Alerting

- [ ] Fehler-Benachrichtigungen
- [ ] Erfolgs-Reports
- [ ] Integration mit Monitoring-Tools

#### 4.6 App Store Launch

- [ ] App Store Optimization
- [ ] Screenshots erstellen
- [ ] Beschreibung schreiben
- [ ] Privacy Policy
- [ ] Terms of Service
- [ ] Support-Kontakt
- [ ] Review-Prozess durchlaufen

### Deliverables

- [ ] Produktionsreife App (iOS)
- [ ] App Store Listing
- [ ] Marketing-Material
- [ ] Support-Dokumentation

---

## Phase 4b: Android-Launch (nach iOS-Launch)

**Dauer:** 4-6 Wochen

### Aufgaben

- [ ] Play Store Optimierung
- [ ] Screenshots erstellen
- [ ] Beschreibung schreiben
- [ ] Privacy Policy
- [ ] Review-Prozess durchlaufen

### Deliverables

- [ ] Android-App im Play Store

---

## Technische Stack-Entscheidungen

### Sprache & Framework (iOS - Primärplattform)

| Komponente | Technologie | Begründung |
|------------|-------------|------------|
| iOS App | Swift, SwiftUI | Native Performance, moderne UI |
| Mindest-iOS-Version | iOS 16 | Ausreichend verbreitet, gute API-Unterstützung |
| Architektur | MVVM + Clean Architecture | Testbarkeit, Wartbarkeit |

### Bibliotheken (iOS)

| Zweck | Bibliothek | Lizenz |
|-------|------------|--------|
| SMB | **AMSMB2 (libsmb2)** | LGPL-2.1 (libsmb2) / MIT (Wrapper) |
| SSH/SFTP | NMSSH | MIT |
| WebDAV | WebDAV-Client-Swift | MIT |
| Google Drive | Google Drive SDK | Apache 2.0 |
| OneDrive | MSAL + Graph SDK | MIT |
| Dropbox | Dropbox SDK | Apache 2.0 |
| Hashing | CryptoKit (native) | Apple |
| Verschlüsselung | CryptoKit (native) | Apple |
| Key-Storage | Keychain (native) | Apple |
| Logging | SwiftLog | Apache 2.0 |
| Dependency Injection | Swinject | MIT |
| Networking | URLSession (native) | Apple |

### Android-Stack (sekundär, später)

| Komponente | Technologie | Begründung |
|------------|-------------|------------|
| Android App | Kotlin, Jetpack Compose | Native Performance, moderne UI |
| Mindest-Android-Version | Android 8.0 (API 26) | Ausreichend verbreitet, moderne APIs |
| SMB | SMBJ | Apache 2.0, ausgereift |
| SSH/SFTP | JSch / Apache MINA sshd | BSD / Apache 2.0 |
| Key-Storage | Android Keystore | Google |
| Background Tasks | WorkManager | Apache 2.0 |

### Server-Hilfsprogramm (SSH)

```bash
#!/bin/bash
# backup-helper.sh - wird auf SSH-Server deployed

case "$1" in
    hash)
        # sha256sum für Datei berechnen
        sha256sum "$2" | cut -d' ' -f1
        ;;
    exists)
        # Prüfen ob Datei existiert
        [ -f "$2" ] && echo "1" || echo "0"
        ;;
    size)
        # Dateigröße in Bytes
        stat -f%z "$2" 2>/dev/null || stat -c%s "$2" 2>/dev/null
        ;;
    *)
        echo "Usage: backup-helper.sh {hash|exists|size} <file>"
        exit 1
        ;;
esac
```

---

## Risikobewertung

### Technische Risiken (iOS)

| Risiko | Wahrscheinlichkeit | Auswirkung | Mitigation |
|--------|-------------------|------------|------------|
| iOS Hintergrundtask-Limits | Hoch | Hoch | Minimaler Hintergrund-Modus, Push-Alternative |
| SMB-Stabilität auf iOS | Mittel | Hoch | Ausgiebiges Testing, Fallback auf FTP/WebDAV |
| libsmb2 sendet PDUs unsigniert → `STATUS_ACCESS_DENIED` | Hoch | Hoch | Signing client-seitig erzwingen (`forceSMBSigning`); im Vorgänger gelöst |
| Re-Kopie aller Dateien, weil Ziel-mtime nicht erhalten | Hoch | Mittel | Zeitstempel am Ziel via `SetInfo`/`setAttributes` setzen (Akzeptanzkriterium) |
| Cloud-API Änderungen | Mittel | Mittel | Abstraktionsschicht, regelmäßige Updates |
| Performance bei großen Dateien | Mittel | Mittel | Chunked Transfer, Progress Tracking |
| Key-Management Sicherheit | Niedrig | Hoch | Keychain, Hardware-Backed Keys |
| iCloud-Integration | Mittel | Mittel | Early Testing mit CloudKit |

### Android-spezifische Risiken (spätere Phase)

| Risiko | Wahrscheinlichkeit | Auswirkung | Mitigation |
|--------|-------------------|------------|------------|
| Scoped Storage (Android 10+) | Hoch | Hoch | Early Implementation, SAF Testing |
| Hintergrundtask-Limits | Mittel | Mittel | WorkManager, JobScheduler |
| Fragmentierung | Hoch | Mittel | Testing auf gängigen Geräten, minSDK Strategie |
| SMB-Stabilität | Niedrig | Mittel | SMBJ ist ausgereift |

### Geschäftliche Risiken

| Risiko | Wahrscheinlichkeit | Auswirkung | Mitigation |
|--------|-------------------|------------|------------|
| Geringe Marktakzeptanz | Mittel | Hoch | Klare Zielgruppe, Nischen-Fokus |
| Konkurrenz durch etablierte Anbieter | Hoch | Mittel | Differenzierung durch SSH, lokale Kontrolle |
| App Store Rejection | Mittel | Hoch | Early Review, Guidelines strikt folgen |
| Monetarisierung | Mittel | Hoch | Freemium-Modell, Abo-Option |
| Höhere Entwicklungskosten (2 Plattformen) | Hoch | Hoch | Sequenzielle Entwicklung, iOS zuerst |

---

## Meilensteine

| Meilenstein | Ziel | Ziel-Datum |
|-------------|------|------------|
| M0: Projekt-Start (iOS) | Phase 0 abgeschlossen | Woche 2 |
| M1: MVP Ready (iOS) | Phase 1 abgeschlossen | Woche 10 |
| M2: Beta Release (iOS) | Phase 2 abgeschlossen | Woche 20 |
| M3: Cloud & SSH (iOS) | Phase 3 abgeschlossen | Woche 32 |
| M4: Launch Ready (iOS) | Phase 4 abgeschlossen | Woche 40 |
| M5: App Store Launch (iOS) | Veröffentlichung iOS | Woche 42 |
| M6: Android-Entwicklungsstart | Phase 0b abgeschlossen | Woche 44 |
| M7: Android-MVP | Phase 1b abgeschlossen | Woche 52 |
| M8: Android-Erweiterungen | Phase 2b+3b abgeschlossen | Woche 64 |
| M9: Play Store Launch (Android) | Veröffentlichung Android | Woche 68 |

---

## Ressourcenplanung

### Personal (iOS-Phase)

| Rolle | Aufwand | Dauer |
|-------|---------|-------|
| iOS Entwickler | 100% | 10 Monate |
| Backend Entwickler (SSH Helper) | 20% | 3 Monate |
| UI/UX Designer | 30% | 2 Monate |
| QA Engineer | 50% | 4 Monate |

### Personal (Android-Phase, nach iOS-Launch)

| Rolle | Aufwand | Dauer |
|-------|---------|-------|
| Android Entwickler | 100% | 6 Monate |
| iOS Entwickler (Support) | 20% | 6 Monate |
| QA Engineer | 50% | 3 Monate |

**Hinweis:** Android-Entwicklung kann parallel zu iOS-Wartung erfolgen. Ein Entwickler kann die Android-Portierung übernehmen, basierend auf den iOS-Erfahrungen.

### Infrastruktur (iOS)

| Ressource | Kosten (geschätzt) |
|-----------|-------------------|
| Apple Developer Account | $99/Jahr |
| CI/CD (GitHub Actions) | $0-50/Monat |
| Test-Geräte iOS | $2.000 einmalig |
| Cloud-Konten (Testing) | $0 (Free Tiers) |
| Server für Testing | $20/Monat |

### Infrastruktur (Android, zusätzlich)

| Ressource | Kosten (geschätzt) |
|-----------|-------------------|
| Google Play Console | $25 einmalig |
| Test-Geräte Android | $1.500 einmalig |

### Testgeräte (empfohlen)

| Plattform | Geräte |
|-----------|--------|
| iOS | iPhone (ältere + neueste), iPad |
| Android | Verschiedene Hersteller (Samsung, Pixel, Xiaomi), verschiedene Android-Versionen (8.0-14) |

---

## Erfolgskriterien

### MVP (Phase 1, iOS)

- [ ] Stabiles Backup von iPhone → SMB
- [ ] Vergleich funktioniert zuverlässig
- [ ] UI ist intuitiv bedienbar
- [ ] Keine kritischen Bugs

### Beta (Phase 2, iOS)

- [ ] Bidirektionale Sync funktioniert
- [ ] Automatisierung läuft stabil
- [ ] 10+ Beta-Tester zufrieden

### Launch (Phase 4, iOS)

- [ ] Alle geplanten Features implementiert
- [ ] App Store Approval erhalten
- [ ] Erste zahlende Kunden
- [ ] Positive Reviews (>4 Sterne)

### Android-Portierung (Phasen 1b-4b)

- [ ] Feature-Parität mit iOS (soweit möglich)
- [ ] Play Store Approval erhalten
- [ ] Konsistente UX zwischen Plattformen

---

## Anhang

### A. iOS-Einschränkungen (Recherche erforderlich)

- Hintergrund-App-Refresh Limits
- Dateisystem-Zugriff (Sandboxing)
- Netzwerk-Zugriff im Hintergrund
- Photos-Zugriff Berechtigungen
- Files App Integration
- NEHotspotNetwork Einschränkungen (WLAN-SSID-Erkennung)

### B. Android-Einschränkungen (für spätere Phase)

- Scoped Storage (Android 10+)
- Background Execution Limits (Android 8+)
- Background Location Restrictions
- Storage Access Framework Limitationen
- WifiManager Berechtigungen (SSID-Erkennung)
- Doze Mode und App Standby
- Hersteller-spezifische Battery Optimizations (Samsung, Xiaomi, etc.)

### C. Cloud-Provider API Limits

| Provider | API Calls/Tag | Upload Limit | Besonderheiten |
|----------|---------------|--------------|----------------|
| Google Drive | ~1M/Tag | 5TB/Tag | Quota-Projekt, OAuth erforderlich |
| OneDrive | 10k/5min | 250GB/Tag | Graph API, MSAL Auth |
| Dropbox | ~100k/Tag | Kein Limit | Chunked Upload, OAuth |
| Nextcloud | Selbst gehostet | Server-abhängig | WebDAV, Basic Auth |

### D. Plattformunterschiede (iOS vs. Android)

| Feature | iOS | Android |
|---------|-----|---------|
| Dateisystem | Sandboxed, Files App | Scoped Storage, SAF |
| Hintergrundtasks | Background Fetch (limitiert) | WorkManager, JobScheduler |
| WLAN-Erkennung | NEHotspotNetwork (eingeschränkt) | WifiManager (Berechtigung) |
| USB-Speicher | File Provider, Lightning/USB-C | USB Host Mode, OTG |
| Key-Storage | Keychain | Keystore |
| Push-Notifications | APNs | FCM |
| Store-Review | Streng, länger | Lockerer, schneller |
| Fragmentierung | Gering (wenige Geräte) | Hoch (viele Geräte/OS-Versionen) |

### E. Glossar

- **MVP**: Minimum Viable Product
- **SMB**: Server Message Block (Netzwerkprotokoll)
- **SFTP**: SSH File Transfer Protocol
- **WebDAV**: Web Distributed Authoring and Versioning
- **OAuth**: Open Authorization (Authentifizierungsstandard)
- **Hash**: Prüfsumme zur Datei-Identifikation
- **SAF**: Storage Access Framework (Android)
- **APNs**: Apple Push Notification service
- **FCM**: Firebase Cloud Messaging
- **MDM**: Mobile Device Management

---

## Verwandtes Projekt-Konzept: Headless Protokoll-Konverter (Cloud-zu-Cloud)

> Eigenständiges Schwester-Projekt, **nicht** Teil der iOS-App. Hier nur als
> Konzept festgehalten.

**Idee:** Ein Sync-/Konverter-Dienst, der direkt zwischen zwei Remote-Endpunkten
synchronisiert (z. B. **Nextcloud → Google Drive**), ohne das Telefon als Motor.

**Warum es zur App passt:** Das `StorageProvider`-Protokoll des MVP ist bereits
protokoll-agnostisch (Quelle → Ziel über eine Zwischendatei). Ein Konverter ist
dasselbe Muster **ohne die lokale Etappe**, nur mit zwei Remote-Providern — und
könnte sich das Provider-Design teilen (anderes Repo, andere Laufzeit/Sprache).

**Wo es läuft — nicht auf dem iPhone:**
- iOS lässt keine dauerhaften Hintergrundprozesse/CLI-Daemons zu → kein 24/7-Sync
  auf dem Telefon.
- Richtiger Ort: ein Gerät, das durchläuft — **NAS, Mini-Server, Nextcloud-Box**
  oder Cloud-VM (gern in Docker).
- Das **iPhone wird Fernsteuerung/Monitoring**, nicht der Motor.

**Prior Art / Messlatte: rclone** (Go, ~70 Backends inkl. WebDAV/Nextcloud, Google
Drive, Dropbox, S3 …) mit `rclone rcd` (Remote-Control-Daemon, HTTP/JSON-API + Web-GUI).
Ein Eigenbau lohnt nur für etwas, das rclone nicht gut kann (z. B. die
BeyondCompare-artige Vergleichs-/Merge-Logik, eigene Policy/UI) — sonst baut man
rclone nach.

**Der eigentliche Knackpunkt: Erreichbarkeit** (zwei getrennte Fragen)

1. *Telefon → Motor:* über die `rcd`-API. Cloud-VM = öffentlicher Endpunkt
   (zwingend Auth + TLS); NAS = nur via Tunnel/VPN von unterwegs.
2. *Motor → Datenquellen:* Cloud↔Cloud unproblematisch (beide öffentlich), aber
   **LAN-Quellen** (SMB, Nextcloud im LAN, FRITZ!Box-NAS, oft hinter CGNAT/dyn. IP)
   erreicht eine Cloud-VM **nicht** ohne Tunnel.

| Motor läuft… | Cloud-Ziele | Heim-NAS | Telefon-Zugriff | Daten/Tokens |
|---|---|---|---|---|
| Cloud-VM | ✅ | ❌ (nur Tunnel) | ✅ einfach | bei Dritt-Anbieter (revDSG) |
| Heim-NAS | ✅ (ausgehend) | ✅ nativ | ⚠️ Tunnel nötig | bei dir |

**Empfohlene Topologie — Mesh-VPN:** NAS, iPhone (+ optional Cloud-Node) per
**Tailscale/WireGuard** in einem privaten Netz. Telefon erreicht den NAS-rclone von
überall ohne Portfreigabe; der Motor erreicht LAN-Quellen nativ *und* ausgehend alle
Clouds; nichts öffentlich exponiert; Daten + OAuth-Tokens bleiben bei dir.

**Alternative ohne VPN:** „outbound-only" — der Motor baut alle Verbindungen selbst
auf (pollt eine Job-Queue, pusht Status). Nichts eingehend offen, funktioniert hinter
CGNAT; Preis ist eine kleine Broker-Komponente in der Mitte.

**Ehrliche Grenze:** Cross-Provider gibt es **kein** echtes server-side copy — Daten
fließen immer durch den Mover (Egress-Kosten, API-Rate-Limits, Token-Verwahrung).

---

## Dokumenten-Historie

| Version | Datum | Autor | Änderung |
|---------|-------|-------|----------|
| 0.1 | 2026-06-20 | - | Erster Entwurf (iOS nur) |
| 0.2 | 2026-06-20 | - | Android-Unterstützung hinzugefügt, KMP-Architektur |
| 0.3 | 2026-06-21 | - | iOS-First Strategie, Android als spätere Phase |
| 0.4 | 2026-06-21 | - | Gegencheck-Korrekturen, FTP/FTPS, iPad-Zweispalter (§2.6), Konzept Headless Protokoll-Konverter |
| 0.5 | 2026-06-21 | - | Cloud-Umsetzungs-Entscheidung Einzel-SDKs vs. librclone-Embedding (§3.1) |
| 0.6 | 2026-06-21 | - | rclone deckt auch SMB/FTP ab; strategische Option „rclone-Frontend" (§3.1) |
| 0.7 | 2026-06-21 | - | Sektion „Positionierung & Abgrenzung": Wettbewerb, Moat, kuratierte Backends, Rolle librclone als Cloud-Motor |
