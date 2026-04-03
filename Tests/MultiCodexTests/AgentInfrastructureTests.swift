import XCTest
@testable import MultiCodex

final class AgentInfrastructureTests: XCTestCase {
    func testRegistryReturnsRegisteredServices() {
        let codex = StubAgentService(agentKind: .codex)
        let pi = StubAgentService(agentKind: .pi)
        let registry = CodingAgentRegistry(services: [codex, pi])

        XCTAssertTrue(registry.supportedAgents.contains(.codex))
        XCTAssertTrue(registry.supportedAgents.contains(.pi))
        XCTAssertTrue(registry.service(for: .codex) === codex)
        XCTAssertTrue(registry.service(for: .pi) === pi)
    }

    func testPiRuntimeResolverResolvesCustomExecutablePath() throws {
        let runtime = try PiRuntimeResolver.resolve(
            customRuntimePath: "/bin/echo",
            fileManager: .default,
            environment: [:]
        )

        XCTAssertEqual(runtime.executableURL.path, "/bin/echo")
        XCTAssertTrue(runtime.display.contains("/bin/echo"))
    }

    func testPiAgentServiceProbeRuntimeUsesConfiguredExecutable() {
        let service = PiAgentService()
        service.customRuntimePath = "/bin/echo"

        let probe = service.probeRuntime()

        XCTAssertTrue(probe.isAvailable)
        XCTAssertNotNil(service.resolutionHint)
    }
}

private final class StubAgentService: CodingAgentServicing {
    let agentKind: AgentKind
    let capabilities: AgentCapabilities
    var customRuntimePath: String?
    var limitsCacheTTLSeconds: Int = CodexAccountService.defaultLimitsCacheTTLSeconds
    var resolutionHint: String?

    init(agentKind: AgentKind) {
        self.agentKind = agentKind
        self.capabilities = agentKind == .pi ? .pi : .codex
    }

    func fetchAccounts() async throws -> AccountsListPayload { AccountsListPayload(accounts: [], currentAccount: nil) }
    func fetchLimits(refreshLive: Bool) async throws -> LimitsPayload { LimitsPayload(results: [], errors: []) }
    func switchAccount(name: String) async throws {}
    func removeAccount(name: String, deleteData: Bool) async throws -> RemoveAccountPayload { RemoveAccountPayload(removedAccount: name, currentAccount: nil) }
    func renameAccount(from oldName: String, to newName: String) async throws -> RenameAccountPayload { RenameAccountPayload(from: oldName, to: newName, currentAccount: nil) }
    func importDefaultAuth(into name: String) async throws -> ImportAccountPayload { ImportAccountPayload(account: name) }
    func importAuth(fromHome homePath: String, into name: String) async throws -> ImportAccountPayload { ImportAccountPayload(account: name) }
    func fetchStatus(name: String) async throws -> AccountStatusPayload { AccountStatusPayload(account: name, exitCode: 0, stdout: "", stderr: "", output: "", checkedAt: "") }
    func fetchStatusForLoginHome(_ homePath: String, accountName: String) async throws -> AccountStatusPayload { AccountStatusPayload(account: accountName, exitCode: 0, stdout: "", stderr: "", output: "", checkedAt: homePath) }
    func openLoginInTerminal(account name: String, loginHome: String?) throws {}
    func openNewAccountLoginInTerminal(newAccountName name: String, loginHome: String?) throws {}
    func loginInApp(account name: String, createIfNeeded: Bool, loginHome: String?) async throws -> String { "ok" }
    func effectiveMulticodexHomePath() -> String { "/tmp" }
    func probeRuntime() -> RuntimeProbe { RuntimeProbe(isAvailable: true, summary: "ok") }
}
