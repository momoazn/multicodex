import XCTest
@testable import MultiCodex

final class CodexRuntimeResolverPathTests: XCTestCase {
    func testFirstExecutablePathKeepsSpacesInPath() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("multicodex test \(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let codex = dir.appendingPathComponent("codex").path
        FileManager.default.createFile(atPath: codex, contents: Data("#!/bin/sh\n".utf8), attributes: [.posixPermissions: 0o755])

        let output = "codex: aliased to something\n\(codex)\n"
        XCTAssertEqual(CodexRuntimeResolver.firstExecutablePath(in: output, fileManager: .default), codex)
    }
}
