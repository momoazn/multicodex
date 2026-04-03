import Foundation

protocol CodingAgentServicing: AnyObject {
    var agentKind: AgentKind { get }
    var capabilities: AgentCapabilities { get }
    var customRuntimePath: String? { get set }
    var limitsCacheTTLSeconds: Int { get set }
    var resolutionHint: String? { get }

    func fetchAccounts() async throws -> AccountsListPayload
    func fetchLimits(refreshLive: Bool) async throws -> LimitsPayload
    func switchAccount(name: String) async throws
    func removeAccount(name: String, deleteData: Bool) async throws -> RemoveAccountPayload
    func renameAccount(from oldName: String, to newName: String) async throws -> RenameAccountPayload
    func importDefaultAuth(into name: String) async throws -> ImportAccountPayload
    func importAuth(fromHome homePath: String, into name: String) async throws -> ImportAccountPayload
    func fetchStatus(name: String) async throws -> AccountStatusPayload
    func fetchStatusForLoginHome(_ homePath: String, accountName: String) async throws -> AccountStatusPayload
    func openLoginInTerminal(account name: String, loginHome: String?) throws
    func openNewAccountLoginInTerminal(newAccountName name: String, loginHome: String?) throws
    func loginInApp(account name: String, createIfNeeded: Bool, loginHome: String?) async throws -> String
    func effectiveMulticodexHomePath() -> String
    func probeRuntime() -> RuntimeProbe
}
