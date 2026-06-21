//
//  SmokeTests.swift
//  MobileBackupSyncTests
//
//  Created on 2026-06-21.
//

import XCTest
@testable import MobileBackupSync

final class SmokeTests: XCTestCase {

    func testSyncOptionDefaults() {
        let options = SyncOptions()
        XCTAssertFalse(options.compareByHash)
        XCTAssertFalse(options.dryRun)
    }

    func testSHA256KnownValue() {
        // SHA-256 von "abc"
        let data = Data("abc".utf8)
        XCTAssertEqual(
            data.sha256,
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        )
    }

    func testCompareResultCounts() {
        var result = CompareResult()
        result.newFiles = [makeItem("a"), makeItem("b")]
        result.modifiedFiles = [makeItem("c")]
        result.unchangedFiles = [makeItem("d")]
        XCTAssertEqual(result.totalFiles, 4)
        XCTAssertEqual(result.filesToTransfer, 3)
    }

    private func makeItem(_ name: String) -> FileItem {
        FileItem(name: name, path: "/\(name)", isDirectory: false, size: 1, modifiedDate: Date())
    }
}
