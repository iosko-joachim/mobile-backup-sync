//
//  TransferManager.swift
//  MobileBackupSync
//
//  Created on 2026-06-21.
//

import Foundation

/// Manager für Datei-Transfers. Arbeitet provider-agnostisch: jede Datei wird
/// über eine temporäre lokale Datei von der Quelle zum Ziel kopiert (kein
/// Vollständig-in-den-RAM-Laden), inklusive Retry-Logik.
final class TransferManager {

    private var isCancelled = false
    private let maxRetries = 3

    /// Transfers ausführen.
    func transfer(
        files: [PlannedFile],
        source: StorageLocation,
        destination: StorageLocation,
        options: SyncOptions,
        onProgress: @escaping (ProgressUpdate) -> Void,
        onError: @escaping (SyncError) -> Void
    ) async throws -> SyncResult {
        isCancelled = false
        let startTime = Date()

        let sourceProvider = source.makeProvider()
        let destProvider = destination.makeProvider()
        try await sourceProvider.connect()
        defer { Task { await sourceProvider.disconnect() } }
        try await destProvider.connect()
        defer { Task { await destProvider.disconnect() } }

        let totalBytes = files.reduce(Int64(0)) { $0 + ($1.action == .delete ? 0 : $1.file.size) }
        var transferredBaseBytes: Int64 = 0
        var filesProcessed = 0
        var errors: [SyncError] = []

        for planned in files {
            guard !isCancelled else {
                return SyncResult(status: .cancelled, filesProcessed: filesProcessed,
                                  errors: errors, duration: Date().timeIntervalSince(startTime))
            }

            do {
                switch planned.action {
                case .delete:
                    try await destProvider.delete(at: planned.file.relativePath)
                case .conflict:
                    // Konflikte erfordern manuelle Auflösung – hier überspringen.
                    continue
                case .copy, .update:
                    let base = transferredBaseBytes
                    try await transferOne(planned, source: sourceProvider, dest: destProvider) { fraction in
                        let bytes = base + Int64(Double(planned.file.size) * fraction)
                        let overall = totalBytes > 0 ? Double(bytes) / Double(totalBytes) : 0
                        onProgress(ProgressUpdate(
                            progress: min(1.0, overall),
                            currentFile: planned.file.relativePath,
                            transferredBytes: bytes,
                            totalBytes: totalBytes,
                            timestamp: Date()
                        ))
                    }
                    transferredBaseBytes += planned.file.size
                }
                filesProcessed += 1
            } catch let error as SyncError {
                errors.append(error)
                onError(error)
            } catch {
                let syncError = SyncError.transferFailed(error.localizedDescription)
                errors.append(syncError)
                onError(syncError)
            }
        }

        return SyncResult(
            status: errors.isEmpty ? .done : .failed("Einige Dateien konnten nicht übertragen werden"),
            filesProcessed: filesProcessed,
            errors: errors,
            duration: Date().timeIntervalSince(startTime)
        )
    }

    /// Eine Datei mit Retry übertragen (Download in Temp → Upload zum Ziel).
    private func transferOne(
        _ planned: PlannedFile,
        source: StorageProvider,
        dest: StorageProvider,
        progress: @escaping (Double) -> Void
    ) async throws {
        let rel = planned.file.relativePath
        var lastError: Error?

        for attempt in 1...maxRetries {
            guard !isCancelled else { throw SyncError.cancelled }

            let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: temp) }

            do {
                try await source.download(at: rel, to: temp) { progress($0 * 0.5) }
                try await dest.upload(from: temp, to: rel) { progress(0.5 + $0 * 0.5) }
                // Zeitstempel der Quelle am Ziel erhalten -> stabiler inkrementeller
                // Abgleich (sonst gilt jede Datei beim nächsten Lauf als geändert).
                await dest.setModificationDate(planned.file.modifiedDate, at: rel)
                return // Erfolg
            } catch {
                lastError = error
                if attempt < maxRetries {
                    // Verbindung könnte tot sein („broken pipe") -> vor dem nächsten
                    // Versuch neu aufbauen.
                    await source.disconnect()
                    await dest.disconnect()
                    try? await source.connect()
                    try? await dest.connect()
                    try? await Task.sleep(nanoseconds: 500_000_000)
                }
            }
        }

        throw lastError ?? SyncError.transferFailed(rel)
    }

    func cancel() {
        isCancelled = true
    }
}
