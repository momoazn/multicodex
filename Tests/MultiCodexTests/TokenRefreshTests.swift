import XCTest
@testable import MultiCodex

final class TokenRefreshTests: XCTestCase {
    func testRefreshStaleTokensDoesNotCrashWithNoAccounts() {
        let service = CodexAccountService()
        service.sandboxHomeDirectory = NSTemporaryDirectory() + "/mc-test-token-\(UUID().uuidString)/home"
        service.sandboxMulticodexHomeDirectory = NSTemporaryDirectory() + "/mc-test-token-\(UUID().uuidString)/config"
        try? FileManager.default.createDirectory(atPath: service.effectiveMulticodexHomePath(), withIntermediateDirectories: true)

        let errors = service.refreshStaleTokensNow()
        XCTAssertTrue(errors.isEmpty)
    }

    func testRefreshStaleTokensSkipsAccountsWithoutAuth() throws {
        let tempDir = NSTemporaryDirectory() + "/mc-test-token-\(UUID().uuidString)"
        let service = CodexAccountService()
        service.sandboxHomeDirectory = (tempDir as NSString).appendingPathComponent("home")
        service.sandboxMulticodexHomeDirectory = (tempDir as NSString).appendingPathComponent("config")
        try FileManager.default.createDirectory(atPath: service.effectiveMulticodexHomePath(), withIntermediateDirectories: true)

        _ = try service.addAccountNow(name: "alpha")
        // No auth file written — should be skipped

        let errors = service.refreshStaleTokensNow()
        XCTAssertTrue(errors.isEmpty, "Should skip accounts without auth")
    }

    func testProactiveRefreshSkipsCurrentAccount() {
        let config = AccountConfigRecord(currentAccount: "alpha", accounts: ["alpha", "beta"])
        XCTAssertEqual(CodexAccountService.accountsForProactiveTokenRefresh(config), ["beta"])
    }

    func testImportWithoutSystemAuthKeepsStoredAuth() throws {
        let tempDir = NSTemporaryDirectory() + "/mc-test-import-\(UUID().uuidString)"
        defer { try? FileManager.default.removeItem(atPath: tempDir) }
        let service = CodexAccountService()
        service.sandboxHomeDirectory = (tempDir as NSString).appendingPathComponent("home")
        service.sandboxMulticodexHomeDirectory = (tempDir as NSString).appendingPathComponent("config")
        try FileManager.default.createDirectory(atPath: service.effectiveMulticodexHomePath(), withIntermediateDirectories: true)
        _ = try service.addAccountNow(name: "alpha")
        let authPath = service.currentPaths().accountAuthPath("alpha")
        try Data("{}".utf8).write(to: URL(fileURLWithPath: authPath))

        XCTAssertThrowsError(try service.importDefaultAuthNow(into: "alpha"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: authPath))
    }
}
