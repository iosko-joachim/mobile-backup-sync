//
//  FTPStorageProvider.swift
//  MobileBackupSync
//
//  Created on 2026-06-21.
//

import Foundation
import Network

/// Provider für plain FTP (passiv) über Apple's `Network.framework`.
///
/// Bewusst **kein** libcurl/rohe Sockets: `NWConnection` ist der von Apple
/// privacy-integrierte Pfad, dadurch greift die „Lokales Netzwerk"-Erlaubnis
/// sauber. Erprobt gegen FRITZ!Box-FTP. FTPS (TLS) ist noch nicht enthalten.
///
/// Alle Pfade in den Protokoll-Methoden sind relativ zu `config.path`. Die
/// Pfad-Normalisierung wird mit dem SMB-Provider geteilt.
final class FTPStorageProvider: StorageProvider, @unchecked Sendable {

    private let config: FTPConfig
    private let rootPath: String
    private let password: String

    private let queue = DispatchQueue(label: "ftp.provider")
    private var control: NWConnection?
    private var lineBuffer = ""
    private var preferList = false      // FRITZ!Box & Co. können kein MLSD -> LIST
    private var mfmtUnsupported = false  // FRITZ!Box kann kein MFMT -> mtime nicht setzbar

    init(config: FTPConfig) {
        self.config = config
        self.rootPath = SMBStorageProvider.normalize(config.path)
        self.password = config.username.isEmpty
            ? ""
            : (SettingsStore.shared.getFTPPassword(host: config.host, username: config.username) ?? "")
    }

    // MARK: - Verbindung

    func connect() async throws {
        guard control == nil else { return }
        lineBuffer = ""
        let conn = try await openConnection(host: cleanHost, port: UInt16(config.port))
        control = conn
        _ = try await readReply()                       // 220 Greeting
        let user = config.username.isEmpty ? "anonymous" : config.username
        let u = try await command("USER \(user)")
        if u.code == 331 {                              // Passwort erwartet
            let p = try await command("PASS \(password)", sensitive: true)
            try expect(p, 230)
        } else if u.code != 230 {
            throw StorageProviderError.networkError("Login fehlgeschlagen (\(u.code))")
        }
        try expect(try await command("TYPE I"), 200)    // Binärmodus
    }

    func disconnect() async {
        if let control {
            try? await send(control, Data("QUIT\r\n".utf8))
            control.cancel()
        }
        control = nil
    }

    // MARK: - Auflisten (rekursiv)

    func listFiles() async throws -> [FileItem] {
        _ = try requireControl()
        var items: [FileItem] = []
        try await walk(rootPath, into: &items)
        return items
    }

    private func walk(_ path: String, into items: inout [FileItem]) async throws {
        let entries: [Entry]
        do {
            entries = try await listing(path: path)
        } catch {
            // Verzeichnis (noch) nicht vorhanden -> nichts zu listen.
            return
        }
        for entry in entries {
            let full = path.isEmpty ? entry.name : "\(path)/\(entry.name)"
            if entry.isDir {
                try await walk(full, into: &items)
            } else {
                items.append(FileItem(
                    name: entry.name,
                    path: full,
                    relativePath: SMBStorageProvider.relative(full, to: rootPath),
                    isDirectory: false,
                    size: entry.size,
                    modifiedDate: entry.modify ?? Date()
                ))
            }
        }
    }

    // MARK: - Lesen / Schreiben

    func readData(at relativePath: String) async throws -> Data {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: temp) }
        try await download(at: relativePath, to: temp) { _ in }
        return try Data(contentsOf: temp)
    }

    func upload(from localURL: URL, to relativePath: String,
                progress: @escaping (Double) -> Void) async throws {
        let control = try requireControl()
        let remote = fullPath(for: relativePath)
        try await ensureDirectory(parentOf: remote)

        let total = Int64((try? localURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        let data = try await openDataConnection()
        defer { data.cancel() }
        try expect1xx(try await command("STOR \(remote)", quiet: true))

        let handle = try FileHandle(forReadingFrom: localURL)
        defer { try? handle.close() }
        var sent: Int64 = 0
        while true {
            let chunk = try handle.read(upToCount: 64 * 1024) ?? Data()
            if chunk.isEmpty { break }
            try await send(data, chunk)
            sent += Int64(chunk.count)
            if total > 0 { progress(min(1.0, Double(sent) / Double(total))) }
        }
        try await sendEOF(data)                          // EOF signalisieren
        try expect2xx(try await readReply())             // 226 Transfer complete
        _ = control
        progress(1.0)
    }

    func download(at relativePath: String, to localURL: URL,
                  progress: @escaping (Double) -> Void) async throws {
        _ = try requireControl()
        let remote = fullPath(for: relativePath)
        let fm = FileManager.default
        if fm.fileExists(atPath: localURL.path) { try fm.removeItem(at: localURL) }
        fm.createFile(atPath: localURL.path, contents: nil)
        let handle = try FileHandle(forWritingTo: localURL)
        defer { try? handle.close() }

        let total = await size(of: remote)
        let data = try await openDataConnection()
        defer { data.cancel() }
        try expect1xx(try await command("RETR \(remote)", quiet: true))

        var received: Int64 = 0
        while true {
            let (chunk, done) = try await receive(data)
            if let chunk, !chunk.isEmpty {
                try handle.write(contentsOf: chunk)
                received += Int64(chunk.count)
                if total > 0 { progress(min(1.0, Double(received) / Double(total))) }
            }
            if done { break }
        }
        try expect2xx(try await readReply())             // 226 Transfer complete
        progress(1.0)
    }

    func delete(at relativePath: String) async throws {
        _ = try requireControl()
        let r = try await command("DELE \(fullPath(for: relativePath))")
        try expect2xx(r)
    }

    func setModificationDate(_ date: Date, at relativePath: String) async {
        // Best effort. Viele Server (FRITZ!Box) können MFMT nicht — nach dem ersten
        // 5xx dauerhaft abschalten. Der Abgleich bleibt über die Größe korrekt.
        guard !mfmtUnsupported, control != nil else { return }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyyMMddHHmmss"
        let stamp = f.string(from: date)
        if let r = try? await command("MFMT \(stamp) \(fullPath(for: relativePath))"),
           (500..<600).contains(r.code) {
            mfmtUnsupported = true
        }
    }

    func getFreeSpace() async throws -> Int64 {
        // FTP kennt keinen standardisierten „freier Speicher"-Befehl.
        Int64.max
    }

    func testConnection() async -> Bool {
        do {
            try await connect()
            _ = try await command("NOOP")
            await disconnect()
            return true
        } catch {
            return false
        }
    }

    // MARK: - Pfad-Helfer

    private var cleanHost: String {
        // evtl. ":port" aus dem Host entfernen (FTP nutzt das eigene Portfeld).
        var h = config.host.trimmingCharacters(in: .whitespaces)
        if let idx = h.lastIndex(of: ":"), Int(h[h.index(after: idx)...]) != nil {
            h = String(h[..<idx])
        }
        return h
    }

    private func fullPath(for relativePath: String) -> String {
        let rel = SMBStorageProvider.normalize(relativePath)
        if rootPath.isEmpty { return rel }
        return rel.isEmpty ? rootPath : "\(rootPath)/\(rel)"
    }

    /// Legt alle Ebenen oberhalb von `remotePath` idempotent per `MKD` an.
    private func ensureDirectory(parentOf remotePath: String) async throws {
        let parts = remotePath.split(separator: "/").dropLast()
        guard !parts.isEmpty else { return }
        var current = ""
        for part in parts {
            current = current.isEmpty ? String(part) : "\(current)/\(part)"
            // 257 = angelegt; 5xx = existiert vermutlich schon -> ignorieren.
            _ = try? await command("MKD \(current)", quiet: true)
        }
    }

    private func size(of remotePath: String) async -> Int64 {
        guard let r = try? await command("SIZE \(remotePath)", quiet: true), r.code == 213 else { return 0 }
        let digits = r.text.dropFirst(3).trimmingCharacters(in: .whitespaces)
        return Int64(digits) ?? 0
    }

    private func requireControl() throws -> NWConnection {
        guard let control else { throw StorageProviderError.notConnected }
        return control
    }

    // MARK: - Verzeichnis-Listing (MLSD mit LIST-Fallback)

    private struct Entry { let name: String; let isDir: Bool; let size: Int64; let modify: Date? }

    private func listing(path: String) async throws -> [Entry] {
        if !preferList {
            if let entries = try await tryListing(cmd: path.isEmpty ? "MLSD" : "MLSD \(path)",
                                                  parser: parseMLSD) {
                return entries
            }
            preferList = true
        }
        if let entries = try await tryListing(cmd: path.isEmpty ? "LIST" : "LIST \(path)",
                                              parser: parseLIST) {
            return entries
        }
        throw StorageProviderError.networkError("Verzeichnis-Listing fehlgeschlagen")
    }

    private func tryListing(cmd: String, parser: (String) -> [Entry]) async throws -> [Entry]? {
        let data = try await openDataConnection()
        defer { data.cancel() }
        let reply = try await command(cmd, quiet: true)
        if (500..<600).contains(reply.code) { return nil }
        try expect1xx(reply)
        var raw = Data()
        while true {
            let (chunk, done) = try await receive(data)
            if let chunk { raw.append(chunk) }
            if done { break }
        }
        try expect2xx(try await readReply())            // 226
        return parser(String(decoding: raw, as: UTF8.self))
    }

    private func parseMLSD(_ text: String) -> [Entry] {
        var result: [Entry] = []
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyyMMddHHmmss"
        for rawLine in text.components(separatedBy: "\r\n") where !rawLine.isEmpty {
            // Format: "fact1=val1;fact2=val2; filename"
            guard let sp = rawLine.firstIndex(of: " ") else { continue }
            let factsPart = String(rawLine[..<sp])
            let name = String(rawLine[rawLine.index(after: sp)...])
            if name == "." || name == ".." || name.isEmpty { continue }
            var type = "", size: Int64 = 0, modify: Date?
            for fact in factsPart.split(separator: ";") {
                let kv = fact.split(separator: "=", maxSplits: 1)
                guard kv.count == 2 else { continue }
                let key = kv[0].lowercased(); let val = String(kv[1])
                switch key {
                case "type": type = val.lowercased()
                case "size": size = Int64(val) ?? 0
                case "modify": modify = f.date(from: String(val.prefix(14)))
                default: break
                }
            }
            if type == "cdir" || type == "pdir" { continue }
            result.append(Entry(name: name, isDir: type == "dir", size: size, modify: modify))
        }
        return result
    }

    /// Parser für klassisches LIST (Unix `ls -l`). Größe wird zuverlässig gelesen;
    /// mtime bleibt offen (Kriterium ist die Größe).
    private func parseLIST(_ text: String) -> [Entry] {
        var result: [Entry] = []
        for line in text.components(separatedBy: "\r\n") where !line.isEmpty {
            guard let first = line.first, first == "d" || first == "-" else { continue }
            let cols = line.split(separator: " ", omittingEmptySubsequences: true)
            guard cols.count >= 9 else { continue }
            let size = Int64(cols[4]) ?? 0
            let name = Self.remainderAfterFields(line, fields: 8)
            if name.isEmpty || name == "." || name == ".." { continue }
            result.append(Entry(name: name, isDir: first == "d", size: size, modify: nil))
        }
        return result
    }

    static func remainderAfterFields(_ line: String, fields: Int) -> String {
        var idx = line.startIndex
        var seen = 0
        var inField = false
        while idx < line.endIndex {
            let c = line[idx]
            if c == " " || c == "\t" {
                if inField {
                    inField = false
                    if seen == fields {
                        return String(line[line.index(after: idx)...]).trimmingCharacters(in: .whitespaces)
                    }
                }
            } else if !inField {
                inField = true; seen += 1
            }
            idx = line.index(after: idx)
        }
        return ""
    }

    // MARK: - Passiver Datenkanal

    private func openDataConnection() async throws -> NWConnection {
        let r = try await command("PASV", quiet: true)
        guard r.code == 227, let p = parsePASVPort(r.text) else {
            throw StorageProviderError.networkError("PASV fehlgeschlagen (\(r.code))")
        }
        // Host der PASV-Antwort ignorieren (NAT/Heim-NAS) — Steuer-Host wiederverwenden.
        return try await openConnection(host: cleanHost, port: p)
    }

    private func parsePASVPort(_ reply: String) -> UInt16? {
        guard let open = reply.firstIndex(of: "("), let close = reply.firstIndex(of: ")") else { return nil }
        let nums = reply[reply.index(after: open)..<close]
            .split(separator: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        guard nums.count == 6 else { return nil }
        return UInt16(nums[4] * 256 + nums[5])
    }

    // MARK: - NWConnection-Primitiven

    private func openConnection(host: String, port: UInt16) async throws -> NWConnection {
        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            throw StorageProviderError.networkError("Ungültiger Port")
        }
        let conn = NWConnection(host: NWEndpoint.Host(host), port: nwPort, using: .tcp)
        let guardState = ResumeGuard()
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            conn.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    guardState.fire { cont.resume() }
                case .failed(let e):
                    guardState.fire { cont.resume(throwing: StorageProviderError.networkError("\(e)")) }
                case .waiting(let e):
                    guardState.fire { cont.resume(throwing: StorageProviderError.networkError("\(e)")) }
                default:
                    break
                }
            }
            conn.start(queue: queue)
        }
        return conn
    }

    private func send(_ conn: NWConnection, _ data: Data) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            conn.send(content: data, completion: .contentProcessed { err in
                if let err { cont.resume(throwing: err) } else { cont.resume() }
            })
        }
    }

    private func sendEOF(_ conn: NWConnection) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            conn.send(content: nil, contentContext: .finalMessage, isComplete: true,
                      completion: .contentProcessed { err in
                if let err { cont.resume(throwing: err) } else { cont.resume() }
            })
        }
    }

    private func receive(_ conn: NWConnection) async throws -> (Data?, Bool) {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<(Data?, Bool), Error>) in
            conn.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, isComplete, err in
                if let err { cont.resume(throwing: err); return }
                cont.resume(returning: (data, isComplete))
            }
        }
    }

    // MARK: - FTP-Kommando/Antwort

    @discardableResult
    private func command(_ cmd: String, sensitive: Bool = false, quiet: Bool = false) async throws -> (code: Int, text: String) {
        guard let control else { throw StorageProviderError.notConnected }
        try await send(control, Data((cmd + "\r\n").utf8))
        return try await readReply()
    }

    private func readReply() async throws -> (code: Int, text: String) {
        let first = try await nextLine()
        guard first.count >= 4, let code = Int(first.prefix(3)) else {
            throw StorageProviderError.networkError("Ungültige Server-Antwort")
        }
        let sepIndex = first.index(first.startIndex, offsetBy: 3)
        if first[sepIndex] == " " { return (code, first) }
        // Mehrzeilige Antwort bis "<code> ..."
        var acc = [first]
        while true {
            let line = try await nextLine()
            acc.append(line)
            if line.count >= 4, Int(line.prefix(3)) == code,
               line[line.index(line.startIndex, offsetBy: 3)] == " " {
                return (code, acc.joined(separator: "\n"))
            }
        }
    }

    private func nextLine() async throws -> String {
        while !lineBuffer.contains("\r\n") {
            guard let control else { throw StorageProviderError.notConnected }
            let (data, isComplete) = try await receive(control)
            if let data, !data.isEmpty { lineBuffer += String(decoding: data, as: UTF8.self) }
            if isComplete && !lineBuffer.contains("\r\n") {
                if lineBuffer.isEmpty { throw StorageProviderError.networkError("Verbindung geschlossen") }
                let rest = lineBuffer; lineBuffer = ""; return rest
            }
        }
        let range = lineBuffer.range(of: "\r\n")!
        let line = String(lineBuffer[..<range.lowerBound])
        lineBuffer.removeSubrange(lineBuffer.startIndex..<range.upperBound)
        return line
    }

    // MARK: - Reply-Erwartungen

    private func expect(_ reply: (code: Int, text: String), _ code: Int) throws {
        if reply.code != code { throw StorageProviderError.networkError("FTP \(reply.code)") }
    }
    private func expect1xx(_ reply: (code: Int, text: String)) throws {
        if !(100..<200).contains(reply.code) { throw StorageProviderError.networkError("FTP \(reply.code)") }
    }
    private func expect2xx(_ reply: (code: Int, text: String)) throws {
        if !(200..<300).contains(reply.code) { throw StorageProviderError.networkError("FTP \(reply.code)") }
    }
}

/// Stellt sicher, dass eine Continuation aus dem `stateUpdateHandler` genau
/// einmal fortgesetzt wird (ready/failed/waiting können mehrfach feuern).
private final class ResumeGuard: @unchecked Sendable {
    private let lock = NSLock()
    private var done = false

    func fire(_ block: @Sendable () -> Void) {
        lock.lock()
        let already = done
        done = true
        lock.unlock()
        if !already { block() }
    }
}
