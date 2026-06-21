//
//  PathLogicTests.swift
//  MobileBackupSyncTests
//
//  Created on 2026-06-21.
//

import XCTest
@testable import MobileBackupSync

final class PathLogicTests: XCTestCase {

    // MARK: - SMB normalize

    func testNormalizeStripsSlashesAndBackslashes() {
        XCTAssertEqual(SMBStorageProvider.normalize("/foo/bar/"), "foo/bar")
        XCTAssertEqual(SMBStorageProvider.normalize("\\foo\\bar"), "foo/bar")
        XCTAssertEqual(SMBStorageProvider.normalize("foo//bar///baz"), "foo/bar/baz")
        XCTAssertEqual(SMBStorageProvider.normalize(""), "")
        XCTAssertEqual(SMBStorageProvider.normalize("/"), "")
    }

    // MARK: - SMB relative

    func testRelativeStripsBasePrefix() {
        XCTAssertEqual(SMBStorageProvider.relative("backup/sub/file.txt", to: "backup"), "sub/file.txt")
        XCTAssertEqual(SMBStorageProvider.relative("file.txt", to: ""), "file.txt")
        XCTAssertEqual(SMBStorageProvider.relative("backup", to: "backup"), "")
        // Pfad ohne passendes Präfix bleibt unverändert.
        XCTAssertEqual(SMBStorageProvider.relative("other/file.txt", to: "backup"), "other/file.txt")
    }

    // MARK: - Local relativePath

    func testLocalRelativePathUnderRoot() {
        let root = URL(fileURLWithPath: "/tmp/sync")
        let nested = URL(fileURLWithPath: "/tmp/sync/a/b/c.txt")
        XCTAssertEqual(LocalStorageProvider.relativePath(of: nested, under: root), "a/b/c.txt")

        let top = URL(fileURLWithPath: "/tmp/sync/x.txt")
        XCTAssertEqual(LocalStorageProvider.relativePath(of: top, under: root), "x.txt")
    }

    // MARK: - Zeitstempel-Erhaltung (inkrementeller Abgleich)

    func testLocalSetModificationDatePreservesTimestamp() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let rel = "sub/file.txt"
        let file = root.appendingPathComponent(rel)
        try fm.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("hi".utf8).write(to: file)

        // Fixes Quelldatum in der Vergangenheit, das am „Ziel" erhalten bleiben soll.
        let wanted = Date(timeIntervalSince1970: 1_600_000_000)
        let provider = LocalStorageProvider(root: root)
        await provider.setModificationDate(wanted, at: rel)

        let actual = try file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        XCTAssertEqual(actual?.timeIntervalSince1970 ?? 0, wanted.timeIntervalSince1970, accuracy: 1.0)
    }

    // MARK: - FTP LIST-Parsing (Dateinamen mit Leerzeichen)

    func testFTPListRemainderAfterFields() {
        let line = "-rw-r--r--  1 owner group   12345 May 23 21:44 Datei mit Leerzeichen.pdf"
        XCTAssertEqual(
            FTPStorageProvider.remainderAfterFields(line, fields: 8),
            "Datei mit Leerzeichen.pdf"
        )

        let dir = "drwxr-xr-x  2 owner group    4096 Jan 02 17:35 Ordner"
        XCTAssertEqual(FTPStorageProvider.remainderAfterFields(dir, fields: 8), "Ordner")
    }
}
